#!/usr/bin/env python3
"""
LinkedIn Cookie Authentication Manager

Manages LinkedIn session cookies for the Expertise Vault scraper.
Supports:
  auth     -- Open browser for user to log in, save cookies
  validate -- Check if saved cookies are still valid
  status   -- Return auth status as JSON
  scrape   -- Scrape posts from a LinkedIn profile using saved cookies

Usage:
    python scripts/linkedin_auth.py auth
    python scripts/linkedin_auth.py auth --method manual --cookies "li_at=...; JSESSIONID=..."
    python scripts/linkedin_auth.py validate
    python scripts/linkedin_auth.py status
    python scripts/linkedin_auth.py scrape --username mitko-vasilev --max-posts 20
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent.parent
COOKIE_PATH = BASE_DIR / "data" / ".linkedin_cookies.json"
AUTH_META_PATH = BASE_DIR / "data" / ".linkedin_auth_meta.json"

LINKEDIN_BASE = "https://www.linkedin.com"
LINKEDIN_LOGIN = f"{LINKEDIN_BASE}/login"
LINKEDIN_VOYAGER = f"{LINKEDIN_BASE}/voyager/api"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_cookies() -> Optional[list]:
    if not COOKIE_PATH.exists():
        return None
    try:
        with open(COOKIE_PATH) as f:
            return json.load(f)
    except Exception:
        return None


def _save_cookies(cookies: list, method: str = "playwright") -> None:
    COOKIE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(COOKIE_PATH, "w") as f:
        json.dump(cookies, f, indent=2)
    os.chmod(COOKIE_PATH, 0o600)

    meta = {
        "authenticated_at": _now_iso(),
        "method": method,
        "cookie_count": len(cookies),
        "last_validated": _now_iso(),
        "valid": True,
    }
    with open(AUTH_META_PATH, "w") as f:
        json.dump(meta, f, indent=2)
    os.chmod(AUTH_META_PATH, 0o600)


def _load_auth_meta() -> Optional[dict]:
    if not AUTH_META_PATH.exists():
        return None
    try:
        with open(AUTH_META_PATH) as f:
            return json.load(f)
    except Exception:
        return None


def _update_auth_meta(updates: dict) -> None:
    meta = _load_auth_meta() or {}
    meta.update(updates)
    with open(AUTH_META_PATH, "w") as f:
        json.dump(meta, f, indent=2)


def _build_cookie_header(cookies: list) -> str:
    return "; ".join(f"{c['name']}={c['value']}" for c in cookies)


def _get_csrf_token(cookies: list) -> Optional[str]:
    for c in cookies:
        if c["name"] == "JSESSIONID":
            val = c["value"].strip('"')
            return f"ajax:{val}"
    return None


def _voyager_headers(cookies: list) -> dict:
    headers = {
        "Cookie": _build_cookie_header(cookies),
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/vnd.linkedin.normalized+json+2.1",
        "x-li-lang": "en_US",
        "x-restli-protocol-version": "2.0.0",
    }
    csrf = _get_csrf_token(cookies)
    if csrf:
        headers["csrf-token"] = csrf
    return headers


# -- Auth: Playwright (preferred) -----------------------------------------


def auth_playwright() -> dict:
    """Open a Chromium browser for user to authenticate with LinkedIn."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return {
            "status": "error",
            "error": "Playwright not installed. Run: pip install playwright && playwright install chromium",
            "fallback": "Use --method manual to paste cookies from DevTools",
        }

    print("Opening LinkedIn login page...", file=sys.stderr)
    print("Please log in. The browser will close automatically after login.", file=sys.stderr)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            args=["--disable-blink-features=AutomationControlled"],
        )
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1280, "height": 800},
        )
        page = context.new_page()
        page.goto(LINKEDIN_LOGIN, wait_until="networkidle")

        try:
            page.wait_for_url(
                re.compile(r"linkedin\.com/(feed|in/|mynetwork|messaging)"),
                timeout=300_000,
            )
        except Exception:
            browser.close()
            return {"status": "error", "error": "Login timed out after 5 minutes"}

        page.wait_for_timeout(2000)
        cookies = context.cookies()
        browser.close()

    if "li_at" not in {c["name"] for c in cookies}:
        return {"status": "error", "error": "Authentication failed -- li_at cookie not found"}

    _save_cookies(cookies, method="playwright")

    li_at = next(c for c in cookies if c["name"] == "li_at")
    expiry = li_at.get("expires", 0)
    expires_at = (
        datetime.fromtimestamp(expiry, tz=timezone.utc).isoformat()
        if expiry > 0
        else "session"
    )

    return {
        "status": "authenticated",
        "method": "playwright",
        "cookie_count": len(cookies),
        "authenticated_at": _now_iso(),
        "li_at_expires": expires_at,
    }


# -- Auth: Manual (fallback) ----------------------------------------------


def auth_manual(cookie_string: Optional[str] = None) -> dict:
    """Accept cookies pasted from browser DevTools."""
    if not cookie_string:
        print("Paste your LinkedIn cookies (name=value; name2=value2).", file=sys.stderr)
        print("Required: li_at, JSESSIONID", file=sys.stderr)
        cookie_string = input("Cookies: ").strip()

    cookies = []
    for pair in cookie_string.split(";"):
        pair = pair.strip()
        if "=" in pair:
            name, value = pair.split("=", 1)
            cookies.append({
                "name": name.strip(),
                "value": value.strip(),
                "domain": ".linkedin.com",
                "path": "/",
            })

    if "li_at" not in {c["name"] for c in cookies}:
        return {"status": "error", "error": "li_at cookie is required"}

    _save_cookies(cookies, method="manual")
    return {
        "status": "authenticated",
        "method": "manual",
        "cookie_count": len(cookies),
        "authenticated_at": _now_iso(),
    }


# -- Validation ------------------------------------------------------------


def validate_cookies() -> dict:
    """Check if saved cookies are still valid via a lightweight LinkedIn request."""
    cookies = _load_cookies()
    if not cookies:
        return {"status": "not_authenticated", "valid": False}

    try:
        req = urllib.request.Request(
            f"{LINKEDIN_VOYAGER}/me",
            headers=_voyager_headers(cookies),
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 200:
                _update_auth_meta({"last_validated": _now_iso(), "valid": True})
                return {"status": "authenticated", "valid": True, "validated_at": _now_iso()}
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            _update_auth_meta({"valid": False, "last_validated": _now_iso()})
            return {"status": "expired", "valid": False, "error": f"HTTP {e.code}: cookies expired"}
    except Exception as e:
        return {"status": "error", "valid": False, "error": str(e)}

    _update_auth_meta({"valid": False, "last_validated": _now_iso()})
    return {"status": "expired", "valid": False}


# -- Status ----------------------------------------------------------------


def get_status() -> dict:
    """Return current auth status."""
    meta = _load_auth_meta()
    cookies = _load_cookies()

    if not cookies or not meta:
        return {"status": "not_authenticated", "valid": False, "has_cookies": cookies is not None}

    needs_revalidation = True
    if meta.get("last_validated"):
        try:
            last = datetime.fromisoformat(meta["last_validated"].replace("Z", "+00:00"))
            needs_revalidation = (datetime.now(timezone.utc) - last) > timedelta(minutes=30)
        except Exception:
            pass

    result = {
        "status": "authenticated" if meta.get("valid") else "expired",
        "valid": meta.get("valid", False),
        "method": meta.get("method", "unknown"),
        "authenticated_at": meta.get("authenticated_at"),
        "last_validated": meta.get("last_validated"),
        "cookie_count": meta.get("cookie_count", 0),
        "needs_revalidation": needs_revalidation,
    }

    li_at = next((c for c in cookies if c["name"] == "li_at"), None)
    if li_at and li_at.get("expires", 0) > 0:
        result["li_at_expires"] = datetime.fromtimestamp(
            li_at["expires"], tz=timezone.utc
        ).isoformat()

    return result


# -- Scraping (cookie-authenticated) --------------------------------------


def scrape_profile_posts(username: str, max_posts: int = 20) -> dict:
    """Scrape recent posts from a LinkedIn profile using saved cookies.

    Strategy:
    1. Try server-rendered HTML with cookie auth (fast, low overhead)
    2. Fall back to Playwright headless for JS-rendered content
    """
    cookies = _load_cookies()
    if not cookies:
        return {"status": "error", "error": "Not authenticated. Run: python scripts/linkedin_auth.py auth"}

    # Try HTML first
    posts = _scrape_html(username, cookies)

    # Fallback to Playwright if HTML yielded nothing
    if not posts:
        posts = _scrape_playwright(username, cookies, max_posts)

    if posts is None:
        posts = []

    return {
        "status": "ok" if posts else "empty",
        "username": username,
        "posts": posts[:max_posts],
        "count": len(posts[:max_posts]),
    }


def _scrape_html(username: str, cookies: list) -> list:
    """Try server-rendered HTML with authenticated cookies."""
    headers = {
        "Cookie": _build_cookie_header(cookies),
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    activity_url = f"{LINKEDIN_BASE}/in/{username}/recent-activity/all/"

    try:
        req = urllib.request.Request(activity_url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            _update_auth_meta({"valid": False})
        return []
    except Exception:
        return []

    return _parse_activity_html(html, username)


def _parse_activity_html(html: str, username: str) -> list:
    """Extract posts from LinkedIn activity HTML."""
    posts = []

    # Pattern: data-urn activity blocks
    blocks = re.findall(
        r'data-urn="urn:li:activity:(\d+)".*?'
        r'<span[^>]*dir="ltr"[^>]*>(.*?)</span>',
        html,
        re.DOTALL,
    )

    # Fallback: any meaningful ltr text spans
    if not blocks:
        spans = re.findall(r'<span[^>]*dir="ltr"[^>]*>(.*?)</span>', html, re.DOTALL)
        for i, raw in enumerate(spans):
            clean = re.sub(r"<[^>]+>", "", raw).strip()
            if len(clean) > 80:
                blocks.append((f"span-{i}", raw))

    seen_texts = set()
    for activity_id, content in blocks:
        text = re.sub(r"<[^>]+>", " ", content).strip()
        text = re.sub(r"\s{2,}", " ", text)
        if len(text) < 30 or text in seen_texts:
            continue
        seen_texts.add(text)

        images = [
            src
            for src in re.findall(r'<img[^>]+src="([^"]+)"', content)
            if "media" in src and "tracking" not in src.lower()
        ]

        post_url = (
            f"{LINKEDIN_BASE}/feed/update/urn:li:activity:{activity_id}"
            if activity_id and not activity_id.startswith("span-")
            else f"{LINKEDIN_BASE}/in/{username}/recent-activity/all/"
        )

        posts.append({
            "id": f"linkedin-scrape-{username}-{activity_id}",
            "text": text[:2000],
            "activity_id": str(activity_id),
            "images": images,
            "url": post_url,
        })

    return posts


def _scrape_playwright(username: str, cookies: list, max_posts: int = 20) -> list:
    """Fallback: Playwright headless for JS-rendered content."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return []

    posts = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
        )

        li_cookies = []
        for c in cookies:
            entry = {
                "name": c["name"],
                "value": c["value"],
                "domain": c.get("domain", ".linkedin.com"),
                "path": c.get("path", "/"),
            }
            if c.get("expires") and c["expires"] > 0:
                entry["expires"] = c["expires"]
            li_cookies.append(entry)
        context.add_cookies(li_cookies)

        page = context.new_page()
        try:
            page.goto(
                f"{LINKEDIN_BASE}/in/{username}/recent-activity/all/",
                wait_until="networkidle",
                timeout=30000,
            )

            # Scroll to load content
            for _ in range(3):
                page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                page.wait_for_timeout(1500)

            elements = page.query_selector_all('[data-urn^="urn:li:activity"]')
            if not elements:
                elements = page.query_selector_all(".feed-shared-update-v2")

            for el in elements[:max_posts]:
                try:
                    text = el.inner_text()
                    text = re.sub(r"\s{2,}", " ", text).strip()
                    if len(text) < 30:
                        continue

                    urn = el.get_attribute("data-urn") or ""
                    m = re.search(r"activity:(\d+)", urn)
                    aid = m.group(1) if m else str(len(posts))

                    imgs = el.query_selector_all('img[src*="media"]')
                    images = [
                        img.get_attribute("src")
                        for img in imgs
                        if img.get_attribute("src")
                    ]

                    posts.append({
                        "id": f"linkedin-scrape-{username}-{aid}",
                        "text": text[:2000],
                        "activity_id": aid,
                        "images": images,
                        "url": f"{LINKEDIN_BASE}/feed/update/urn:li:activity:{aid}"
                        if m
                        else f"{LINKEDIN_BASE}/in/{username}/recent-activity/all/",
                    })
                except Exception:
                    continue
        except Exception as e:
            print(f"Playwright scrape error: {e}", file=sys.stderr)

        browser.close()

    return posts


# -- CLI -------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="LinkedIn Cookie Authentication Manager")
    sub = parser.add_subparsers(dest="command", required=True)

    auth_p = sub.add_parser("auth", help="Authenticate with LinkedIn")
    auth_p.add_argument("--method", choices=["playwright", "manual"], default="playwright")
    auth_p.add_argument("--cookies", type=str, help="Cookie string for manual method")

    sub.add_parser("validate", help="Validate saved cookies")
    sub.add_parser("status", help="Show authentication status")

    scrape_p = sub.add_parser("scrape", help="Scrape posts from a LinkedIn profile")
    scrape_p.add_argument("--username", required=True, help="LinkedIn username (URL slug)")
    scrape_p.add_argument("--max-posts", type=int, default=20)

    args = parser.parse_args()

    if args.command == "auth":
        result = auth_manual(args.cookies) if args.method == "manual" else auth_playwright()
    elif args.command == "validate":
        result = validate_cookies()
    elif args.command == "status":
        result = get_status()
    elif args.command == "scrape":
        result = scrape_profile_posts(args.username, args.max_posts)
    else:
        parser.print_help()
        return

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
