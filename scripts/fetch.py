#!/usr/bin/env python3
"""
Authority fetcher — periodically pulls new content from tracked expert sources.

Supports:
  github       — GitHub public repos + events via REST API (no auth required)
  rss          — Any RSS/Atom feed via feedparser
  html         — Generic HTML page with basic content extraction
  linkedin-rss — LinkedIn via rss.app RSS bridge (requires rss.app feed URL)
  linkedin / browser-only — Fallback: returns instructions for userscript sync

Usage:
    python scripts/fetch.py --slug mitko-vasilev
    python scripts/fetch.py --slug owl-listener --dry-run
    python scripts/fetch.py --list-due
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
DEFAULT_DB_PATH = DATA_DIR / "expertise.db"

# ── helpers ──────────────────────────────────────────────────────────────────

def _http_get(url: str, headers: Optional[dict] = None, timeout: int = 15) -> Optional[bytes]:
    """Simple HTTP GET using stdlib only (no requests dep required)."""
    req_headers = {
        "User-Agent": "Claude-Expertise-Vault/1.0 (github.com/peguesj/claude-expertise-vault)",
        "Accept": "application/json, text/html, */*",
    }
    if headers:
        req_headers.update(headers)
    try:
        req = urllib.request.Request(url, headers=req_headers)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except Exception as e:
        print(f"  [fetch] GET {url} failed: {e}", file=sys.stderr)
        return None


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _slug_from_text(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def _is_rss_app_url(url: str) -> bool:
    """Check if a URL is an rss.app feed URL."""
    return bool(re.match(r"https?://(www\.)?rss\.app/feeds?/", url))


def _is_linkedin_url(url: str) -> bool:
    """Check if a URL is a LinkedIn profile/company/newsletter URL."""
    return bool(re.match(r"https?://(www\.)?linkedin\.com/", url))


def _has_linkedin_cookies() -> bool:
    """Check if LinkedIn auth cookies exist and metadata says they're valid."""
    meta_path = BASE_DIR / "data" / ".linkedin_auth_meta.json"
    if not meta_path.exists():
        return False
    try:
        with open(meta_path) as f:
            meta = json.load(f)
        return meta.get("valid", False)
    except Exception:
        return False


def _load_seen_ids(slug: str) -> set:
    """Load existing post IDs for an author to avoid duplicates."""
    path = RAW_DIR / f"{slug}.jsonl"
    seen = set()
    if path.exists():
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        seen.add(json.loads(line).get("id", ""))
                    except Exception:
                        pass
    return seen


def _append_posts(slug: str, posts: list) -> int:
    """Append new posts to the raw JSONL file. Returns count written."""
    if not posts:
        return 0
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    path = RAW_DIR / f"{slug}.jsonl"
    written = 0
    with open(path, "a") as f:
        for post in posts:
            f.write(json.dumps(post, ensure_ascii=False) + "\n")
            written += 1
    return written


# ── GitHub adapter ────────────────────────────────────────────────────────────

def fetch_github(authority: dict, seen_ids: set, dry_run: bool = False) -> list:
    """Fetch public repos and recent events from a GitHub user profile."""
    profile_url = authority.get("profile_url", "")
    # Extract username from URL: https://github.com/username
    match = re.search(r"github\.com/([^/?\s]+)", profile_url)
    if not match:
        return []
    username = match.group(1)
    slug = authority["slug"]

    posts = []

    # 1. Public repos — each repo becomes a "post" summarising its purpose
    repos_url = f"https://api.github.com/users/{username}/repos?sort=updated&per_page=30"
    raw = _http_get(repos_url, headers={"Accept": "application/vnd.github.v3+json"})
    if raw:
        try:
            repos = json.loads(raw)
            for repo in repos:
                if repo.get("fork"):
                    continue  # skip forks
                post_id = f"github-{username}-{repo['name']}"
                if post_id in seen_ids:
                    continue
                description = repo.get("description") or ""
                topics = repo.get("topics") or []
                text_parts = [
                    f"GitHub repository: {repo['full_name']}",
                    description,
                    f"Stars: {repo.get('stargazers_count', 0)}, Forks: {repo.get('forks_count', 0)}",
                ]
                if topics:
                    text_parts.append(f"Topics: {', '.join(topics)}")
                if repo.get("homepage"):
                    text_parts.append(f"Homepage: {repo['homepage']}")
                text = "\n".join(p for p in text_parts if p)
                if len(text) < 20:
                    continue
                posts.append({
                    "id": post_id,
                    "author": authority["name"],
                    "platform": "github",
                    "url": repo["html_url"],
                    "text": text,
                    "scraped_date": _now_iso(),
                    "likes": repo.get("stargazers_count", 0),
                    "comments": repo.get("open_issues_count", 0),
                    "reposts": repo.get("forks_count", 0),
                    "tags": topics,
                    "media": [],
                    "links": [repo["html_url"]],
                    "authority_slug": slug,
                })
        except Exception as e:
            print(f"  [github] repos parse error: {e}", file=sys.stderr)

    # 2. Recent public events — PushEvent commit messages as tips
    events_url = f"https://api.github.com/users/{username}/events/public?per_page=30"
    raw = _http_get(events_url, headers={"Accept": "application/vnd.github.v3+json"})
    if raw:
        try:
            events = json.loads(raw)
            for event in events:
                etype = event.get("type", "")
                if etype not in ("PushEvent", "CreateEvent"):
                    continue
                event_id = f"github-event-{event['id']}"
                if event_id in seen_ids:
                    continue
                payload = event.get("payload", {})
                repo_name = event.get("repo", {}).get("name", "")
                text_parts = [f"GitHub {etype} on {repo_name}"]
                if etype == "PushEvent":
                    commits = payload.get("commits", [])[:3]
                    for c in commits:
                        msg = (c.get("message") or "").split("\n")[0]
                        if msg:
                            text_parts.append(f"- {msg}")
                elif etype == "CreateEvent":
                    ref_type = payload.get("ref_type", "")
                    desc = payload.get("description") or ""
                    text_parts.append(f"Created {ref_type}: {desc}")
                text = "\n".join(p for p in text_parts if p)
                if len(text) < 30:
                    continue
                posts.append({
                    "id": event_id,
                    "author": authority["name"],
                    "platform": "github",
                    "url": f"https://github.com/{repo_name}",
                    "text": text,
                    "scraped_date": _now_iso(),
                    "likes": 0,
                    "comments": 0,
                    "reposts": 0,
                    "tags": [],
                    "media": [],
                    "links": [f"https://github.com/{repo_name}"],
                    "authority_slug": slug,
                })
        except Exception as e:
            print(f"  [github] events parse error: {e}", file=sys.stderr)

    return posts


# ── RSS adapter ───────────────────────────────────────────────────────────────

def fetch_rss(authority: dict, seen_ids: set, dry_run: bool = False) -> list:
    """Fetch entries from an RSS or Atom feed."""
    fetch_url = authority.get("fetch_url") or authority.get("profile_url", "")
    slug = authority["slug"]
    posts = []

    raw = _http_get(fetch_url, headers={"Accept": "application/rss+xml, application/atom+xml, text/xml, */*"})
    if not raw:
        return []

    # Try feedparser if available, fall back to basic regex
    try:
        import feedparser
        feed = feedparser.parse(raw)
        for entry in feed.entries:
            entry_id = entry.get("id") or entry.get("link", "")
            post_id = f"rss-{slug}-{_slug_from_text(entry_id)[:32]}"
            if post_id in seen_ids:
                continue
            title = entry.get("title", "")
            summary = entry.get("summary") or entry.get("content", [{}])[0].get("value", "")
            # Strip HTML tags
            summary = re.sub(r"<[^>]+>", " ", summary).strip()
            text = f"{title}\n\n{summary}".strip()
            if len(text) < 30:
                continue
            published = entry.get("published") or entry.get("updated") or _now_iso()
            posts.append({
                "id": post_id,
                "author": authority["name"],
                "platform": "blog",
                "url": entry.get("link", fetch_url),
                "text": text,
                "scraped_date": _now_iso(),
                "time_relative": published,
                "likes": 0,
                "comments": 0,
                "reposts": 0,
                "tags": [t.get("term", "") for t in entry.get("tags", []) if t.get("term")],
                "media": [],
                "links": [entry.get("link", fetch_url)],
                "authority_slug": slug,
            })
    except ImportError:
        # Basic XML extraction without feedparser
        text_raw = raw.decode("utf-8", errors="replace")
        items = re.findall(r"<item>(.*?)</item>", text_raw, re.DOTALL)
        items += re.findall(r"<entry>(.*?)</entry>", text_raw, re.DOTALL)
        for item in items:
            title_m = re.search(r"<title[^>]*>(.*?)</title>", item, re.DOTALL)
            link_m = re.search(r"<link[^>]*>(.*?)</link>|<link[^>]+href=['\"]([^'\"]+)['\"]", item, re.DOTALL)
            desc_m = re.search(r"<description[^>]*>(.*?)</description>|<summary[^>]*>(.*?)</summary>", item, re.DOTALL)
            title = re.sub(r"<[^>]+>|<!\[CDATA\[|\]\]>", "", title_m.group(1) if title_m else "").strip()
            link = (link_m.group(1) or link_m.group(2) if link_m else "").strip() or fetch_url
            desc = re.sub(r"<[^>]+>|<!\[CDATA\[|\]\]>", " ", desc_m.group(1) or desc_m.group(2) if desc_m else "").strip()
            text = f"{title}\n\n{desc}".strip()
            if len(text) < 30:
                continue
            post_id = f"rss-{slug}-{_slug_from_text(link)[:32]}"
            if post_id in seen_ids:
                continue
            posts.append({
                "id": post_id,
                "author": authority["name"],
                "platform": "blog",
                "url": link,
                "text": text,
                "scraped_date": _now_iso(),
                "likes": 0, "comments": 0, "reposts": 0,
                "tags": [], "media": [], "links": [link],
                "authority_slug": slug,
            })

    return posts


# ── HTML adapter ──────────────────────────────────────────────────────────────

def fetch_html(authority: dict, seen_ids: set, dry_run: bool = False) -> list:
    """Fetch and extract content from a generic HTML page."""
    fetch_url = authority.get("fetch_url") or authority.get("profile_url", "")
    slug = authority["slug"]
    raw = _http_get(fetch_url)
    if not raw:
        return []

    text_raw = raw.decode("utf-8", errors="replace")

    # Extract page title
    title_m = re.search(r"<title[^>]*>(.*?)</title>", text_raw, re.IGNORECASE | re.DOTALL)
    title = re.sub(r"<[^>]+>", "", title_m.group(1) if title_m else "").strip()

    # Strip scripts/styles then extract text
    text_raw = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", text_raw, flags=re.DOTALL | re.IGNORECASE)
    text_raw = re.sub(r"<[^>]+>", " ", text_raw)
    text_raw = re.sub(r"\s{2,}", " ", text_raw).strip()

    # Trim to ~2000 chars — we only want a representative snapshot
    content = text_raw[:2000].strip()
    text = f"{title}\n\n{content}".strip() if title else content

    if len(text) < 50:
        return []

    post_id = f"html-{slug}-{_slug_from_text(fetch_url)[:32]}"
    if post_id in seen_ids:
        return []

    return [{
        "id": post_id,
        "author": authority["name"],
        "platform": authority.get("platform", "other"),
        "url": fetch_url,
        "text": text,
        "scraped_date": _now_iso(),
        "likes": 0, "comments": 0, "reposts": 0,
        "tags": [], "media": [], "links": [fetch_url],
        "authority_slug": slug,
    }]


# ── LinkedIn RSS adapter (via rss.app) ───────────────────────────────────────

def _extract_linkedin_images(html_text: str) -> list:
    """Pull image URLs from rss.app HTML content (LinkedIn embeds images inline)."""
    return re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', html_text)


def _extract_linkedin_links(html_text: str) -> list:
    """Pull outbound links from rss.app HTML content."""
    links = re.findall(r'<a[^>]+href=["\']([^"\']+)["\']', html_text)
    return [l for l in links if "linkedin.com" in l or not l.startswith("#")]


def fetch_linkedin_rss(authority: dict, seen_ids: set, dry_run: bool = False) -> list:
    """Fetch LinkedIn posts via an rss.app RSS feed bridge.

    Requires authority['fetch_url'] to be a valid rss.app feed URL
    (e.g. https://rss.app/feeds/<id>.xml). The feed is standard RSS/Atom
    but entries are LinkedIn posts — we normalize them to our schema with
    platform='linkedin' and extract embedded images/links.
    """
    fetch_url = authority.get("fetch_url", "")
    if not fetch_url:
        return []

    slug = authority["slug"]
    profile_url = authority.get("profile_url", "")
    posts = []

    raw = _http_get(fetch_url, headers={
        "Accept": "application/rss+xml, application/atom+xml, text/xml, */*",
    })
    if not raw:
        return []

    # Parse with feedparser if available, fallback to regex
    try:
        import feedparser
        feed = feedparser.parse(raw)
        for entry in feed.entries:
            entry_id = entry.get("id") or entry.get("link", "")
            post_id = f"linkedin-rss-{slug}-{_slug_from_text(entry_id)[:40]}"
            if post_id in seen_ids:
                continue

            title = entry.get("title", "")
            # rss.app preserves HTML in summary/content — extract text + media
            raw_html = entry.get("summary") or ""
            if not raw_html and entry.get("content"):
                raw_html = entry["content"][0].get("value", "")

            media = _extract_linkedin_images(raw_html)
            links = _extract_linkedin_links(raw_html)

            # Clean HTML to plain text
            text_body = re.sub(r"<[^>]+>", " ", raw_html).strip()
            text_body = re.sub(r"\s{2,}", " ", text_body)
            text = f"{title}\n\n{text_body}".strip() if title != text_body else text_body

            if len(text) < 30:
                continue

            published = entry.get("published") or entry.get("updated") or _now_iso()
            entry_link = entry.get("link", profile_url)

            posts.append({
                "id": post_id,
                "author": authority["name"],
                "platform": "linkedin",
                "url": entry_link,
                "text": text,
                "date": published,
                "scraped_date": _now_iso(),
                "likes": 0,
                "comments": 0,
                "reposts": 0,
                "tags": [t.get("term", "") for t in entry.get("tags", []) if t.get("term")],
                "media": media,
                "links": links or [entry_link],
                "authority_slug": slug,
            })
    except ImportError:
        # Fallback: basic XML parsing without feedparser
        text_raw = raw.decode("utf-8", errors="replace")
        items = re.findall(r"<item>(.*?)</item>", text_raw, re.DOTALL)
        items += re.findall(r"<entry>(.*?)</entry>", text_raw, re.DOTALL)
        for item in items:
            title_m = re.search(r"<title[^>]*>(.*?)</title>", item, re.DOTALL)
            link_m = re.search(r"<link[^>]*>(.*?)</link>|<link[^>]+href=['\"]([^'\"]+)['\"]", item, re.DOTALL)
            desc_m = re.search(r"<description[^>]*>(.*?)</description>|<summary[^>]*>(.*?)</summary>", item, re.DOTALL)

            title = re.sub(r"<[^>]+>|<!\[CDATA\[|\]\]>", "", title_m.group(1) if title_m else "").strip()
            link = ""
            if link_m:
                link = (link_m.group(1) or link_m.group(2) or "").strip()
            link = link or profile_url

            raw_desc = (desc_m.group(1) or desc_m.group(2)) if desc_m else ""
            media = _extract_linkedin_images(raw_desc)
            links_found = _extract_linkedin_links(raw_desc)
            desc = re.sub(r"<[^>]+>|<!\[CDATA\[|\]\]>", " ", raw_desc).strip()
            desc = re.sub(r"\s{2,}", " ", desc)

            text = f"{title}\n\n{desc}".strip()
            if len(text) < 30:
                continue

            post_id = f"linkedin-rss-{slug}-{_slug_from_text(link)[:40]}"
            if post_id in seen_ids:
                continue

            posts.append({
                "id": post_id,
                "author": authority["name"],
                "platform": "linkedin",
                "url": link,
                "text": text,
                "scraped_date": _now_iso(),
                "likes": 0, "comments": 0, "reposts": 0,
                "tags": [], "media": media, "links": links_found or [link],
                "authority_slug": slug,
            })

    return posts


# ── LinkedIn Scraper adapter (cookie-authenticated) ──────────────────────────

def fetch_linkedin_scraper(authority: dict, seen_ids: set, dry_run: bool = False) -> list:
    """Fetch LinkedIn posts via authenticated cookie-based scraping.

    Uses scripts/linkedin_auth.py to scrape a profile's recent activity
    with stored session cookies. Requires prior authentication.
    """
    profile_url = authority.get("profile_url", "")
    slug = authority["slug"]

    # Extract username from LinkedIn URL
    match = re.search(r"linkedin\.com/in/([^/?#\s]+)", profile_url)
    if not match:
        # Try company URL
        match = re.search(r"linkedin\.com/company/([^/?#\s]+)", profile_url)
    if not match:
        return []

    username = match.group(1).rstrip("/")

    # Call linkedin_auth.py scrape
    import subprocess
    auth_script = BASE_DIR / "scripts" / "linkedin_auth.py"
    try:
        result = subprocess.run(
            [sys.executable, str(auth_script), "scrape", "--username", username, "--max-posts", "30"],
            cwd=str(BASE_DIR),
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            print(f"  [linkedin-scraper] scrape failed: {result.stderr}", file=sys.stderr)
            return []
        data = json.loads(result.stdout)
    except Exception as e:
        print(f"  [linkedin-scraper] error: {e}", file=sys.stderr)
        return []

    if data.get("status") in ("error", "auth_expired"):
        print(f"  [linkedin-scraper] {data.get('error', 'unknown error')}", file=sys.stderr)
        return []

    posts = []
    for raw_post in data.get("posts", []):
        post_id = raw_post.get("id", f"linkedin-scrape-{slug}-{len(posts)}")
        if post_id in seen_ids:
            continue

        text = raw_post.get("text", "")
        if len(text) < 30:
            continue

        posts.append({
            "id": post_id,
            "author": authority["name"],
            "platform": "linkedin",
            "url": raw_post.get("url", profile_url),
            "text": text,
            "scraped_date": _now_iso(),
            "likes": 0,
            "comments": 0,
            "reposts": 0,
            "tags": [],
            "media": raw_post.get("images", []),
            "links": [raw_post.get("url", profile_url)],
            "authority_slug": slug,
        })

    return posts


# ── RSSHub adapter (self-hosted LinkedIn company feeds) ──────────────────────

def _is_rsshub_url(url: str) -> bool:
    """Detect RSSHub URLs (self-hosted or public instances)."""
    return bool(re.match(r"https?://.*/(linkedin|rsshub)/", url)) or "rsshub" in url.lower()


def fetch_rsshub(authority: dict, seen_ids: set, dry_run: bool = False) -> list:
    """Fetch from a self-hosted RSSHub instance. Wraps the RSS adapter with LinkedIn normalization."""
    # RSSHub outputs standard RSS — reuse the RSS adapter but fix platform
    posts = fetch_rss(authority, seen_ids, dry_run=dry_run)
    for post in posts:
        post["platform"] = "linkedin"
    return posts


# ── Dispatch ──────────────────────────────────────────────────────────────────

ADAPTERS = {
    "github": fetch_github,
    "rss": fetch_rss,
    "html": fetch_html,
    "linkedin-rss": fetch_linkedin_rss,
    "linkedin-scraper": fetch_linkedin_scraper,
    "rsshub": fetch_rsshub,
}


def fetch_authority(slug: str, db_path: Optional[str] = None, dry_run: bool = False) -> dict:
    """Fetch new content for the given authority slug.

    Returns:
        {"slug": ..., "new_posts": N, "status": "ok"|"browser-only"|"error", "error": ...}
    """
    # Load authority from DB
    sys.path.insert(0, str(BASE_DIR / "scripts"))
    import database as db_mod
    conn = db_mod.init_db(db_path)
    authority = db_mod.get_authority(conn, slug)
    conn.close()

    if not authority:
        return {"slug": slug, "status": "error", "error": f"Authority '{slug}' not found"}

    status = authority.get("status", "active")
    config = authority.get("scrape_config", {})
    platform = authority.get("platform", "")
    fetch_url = authority.get("fetch_url") or ""

    # Smart LinkedIn routing: try best available adapter
    if platform == "linkedin":
        explicit_adapter = config.get("adapter", "")
        if explicit_adapter and explicit_adapter in ADAPTERS:
            adapter_name = explicit_adapter
        elif fetch_url and _is_rss_app_url(fetch_url):
            adapter_name = "linkedin-rss"
        elif fetch_url and _is_rsshub_url(fetch_url):
            adapter_name = "rsshub"
        elif _has_linkedin_cookies():
            adapter_name = "linkedin-scraper"
        elif status == "browser-only" or not fetch_url:
            hints = [
                "Options to enable automatic sync:",
                "  1. Authenticate: python scripts/linkedin_auth.py auth",
                "  2. RSS bridge: https://rss.app/rss-feed/linkedin (set as fetch_url)",
                "  3. Self-hosted: RSSHub /linkedin/company/<id>/posts (set as fetch_url)",
            ]
            return {
                "slug": slug,
                "status": "browser-only",
                "message": f"'{authority['name']}' requires setup for automatic sync.",
                "hints": hints,
                "profile_url": authority["profile_url"],
            }
        else:
            adapter_name = "linkedin-rss"  # Default: try RSS with whatever fetch_url
    elif status == "browser-only":
        return {
            "slug": slug,
            "status": "browser-only",
            "message": f"'{authority['name']}' requires browser sync via the Tampermonkey userscript.",
            "profile_url": authority["profile_url"],
        }
    elif status == "paused":
        return {"slug": slug, "status": "paused"}
    else:
        adapter_name = config.get("adapter", "")
        if not adapter_name:
            adapter_name = "github" if platform == "github" else "rss" if platform in ("blog", "rss") else "html"

    adapter = ADAPTERS.get(adapter_name)
    if not adapter:
        return {"slug": slug, "status": "error", "error": f"Unknown adapter '{adapter_name}'"}

    seen_ids = _load_seen_ids(slug)

    try:
        posts = adapter(authority, seen_ids, dry_run=dry_run)
    except Exception as e:
        return {"slug": slug, "status": "error", "error": str(e)}

    new_count = len(posts)

    if dry_run:
        print(f"  [dry-run] {slug}: would write {new_count} posts", file=sys.stderr)
        return {"slug": slug, "status": "dry-run", "new_posts": new_count, "posts": posts}

    if posts:
        written = _append_posts(slug, posts)
        # Trigger DB import
        db_script = BASE_DIR / "scripts" / "database.py"
        import subprocess
        subprocess.run(
            [sys.executable, str(db_script), "import", "--author", slug],
            cwd=str(BASE_DIR), capture_output=True
        )

    # Update sync state in DB
    conn = db_mod.init_db(db_path)
    db_mod.update_authority_sync(conn, slug, new_posts=new_count)
    conn.close()

    return {"slug": slug, "status": "ok", "new_posts": new_count}


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Fetch new content from tracked authority sources",
    )
    parser.add_argument("--db", type=str, default=None, help="Database path")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--slug", type=str, help="Authority slug to fetch")
    group.add_argument("--list-due", action="store_true", help="Print due authority slugs and exit")
    group.add_argument("--sync-all-due", action="store_true", help="Sync all due authorities")
    parser.add_argument("--dry-run", action="store_true", help="Fetch but do not write posts")

    args = parser.parse_args()

    if args.list_due:
        sys.path.insert(0, str(BASE_DIR / "scripts"))
        import database as db_mod
        conn = db_mod.init_db(args.db)
        due = db_mod.list_due_authorities(conn)
        conn.close()
        print(json.dumps({"due": [d["slug"] for d in due], "count": len(due)}))
        return

    if args.sync_all_due:
        sys.path.insert(0, str(BASE_DIR / "scripts"))
        import database as db_mod
        conn = db_mod.init_db(args.db)
        due = db_mod.list_due_authorities(conn)
        conn.close()
        results = []
        for auth in due:
            result = fetch_authority(auth["slug"], db_path=args.db, dry_run=args.dry_run)
            results.append(result)
            print(f"  {auth['slug']}: {result['status']} ({result.get('new_posts', 0)} new)", file=sys.stderr)
        print(json.dumps({"results": results, "synced": len(results)}))
        return

    result = fetch_authority(args.slug, db_path=args.db, dry_run=args.dry_run)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
