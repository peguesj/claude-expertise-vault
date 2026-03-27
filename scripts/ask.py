#!/usr/bin/env python3
"""
AI-powered Q&A grounded in the Claude Code expertise database.

Combines vector search, taxonomy lookup, and resource discovery
to answer questions using real expert knowledge as foundation.

Usage:
    python scripts/ask.py "what is the best stack for local AI coding agents?"
    python scripts/ask.py --verbose "how do agent swarms coordinate?"
    python scripts/ask.py --json "worktree patterns for parallel development"
    python scripts/ask.py --no-ai "what hardware for local inference?"
    python scripts/ask.py --top-k 15 "self-improving agents"
"""

import json
import argparse
import csv
import os
import sys
import textwrap
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "data" / "expertise.db"
MANIFEST_PATH = BASE_DIR / "data" / "manifest.csv"
PROCESSED_DIR = BASE_DIR / "data" / "processed"
RAW_DIR = BASE_DIR / "data" / "raw"

# Add scripts dir to path so we can import search
sys.path.insert(0, str(Path(__file__).resolve().parent))
from search import search


# ---------------------------------------------------------------------------
# Taxonomy & metadata lookup from manifest CSV + processed JSONL
# ---------------------------------------------------------------------------

def _load_manifest() -> dict:
    """Load the manifest CSV into a dict keyed by post ID."""
    if not MANIFEST_PATH.exists():
        return {}
    posts = {}
    with open(MANIFEST_PATH, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            posts[row["id"]] = row
    return posts


def _load_processed_posts() -> dict:
    """Load all processed JSONL chunks into a dict keyed by post_id.

    Returns a mapping of post_id -> list of chunk dicts.
    """
    posts = {}
    for jsonl_path in sorted(PROCESSED_DIR.glob("*.jsonl")):
        with open(jsonl_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    chunk = json.loads(line)
                    pid = chunk.get("post_id", "")
                    if pid not in posts:
                        posts[pid] = []
                    posts[pid].append(chunk)
                except json.JSONDecodeError:
                    continue
    return posts


def _sqlite_lookup(post_ids: list[str]) -> dict:
    """Query the SQLite database for taxonomy, resources, and insights.

    Returns a dict with keys: taxonomy_tags, resources, insights.
    Falls back gracefully if the DB does not exist.
    """
    result = {"taxonomy_tags": [], "resources": [], "insights": []}

    if not DB_PATH.exists():
        return result

    try:
        import sqlite3
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row

        # Taxonomy tags
        try:
            placeholders = ",".join("?" for _ in post_ids)
            rows = conn.execute(
                f"SELECT DISTINCT tag FROM post_tags WHERE post_id IN ({placeholders})",
                post_ids,
            ).fetchall()
            result["taxonomy_tags"] = [r["tag"] for r in rows]
        except sqlite3.OperationalError:
            pass

        # Resources
        try:
            rows = conn.execute(
                f"SELECT url, title, type FROM resources WHERE post_id IN ({placeholders})",
                post_ids,
            ).fetchall()
            result["resources"] = [dict(r) for r in rows]
        except sqlite3.OperationalError:
            pass

        # Insights
        try:
            rows = conn.execute(
                f"SELECT text FROM insights WHERE post_id IN ({placeholders})",
                post_ids,
            ).fetchall()
            result["insights"] = [r["text"] for r in rows]
        except sqlite3.OperationalError:
            pass

        conn.close()
    except Exception:
        pass

    return result


def _get_tags_from_manifest(post_ids: list[str], manifest: dict) -> list[str]:
    """Extract unique taxonomy tags from the manifest for the given post IDs."""
    tags = set()
    for pid in post_ids:
        entry = manifest.get(pid, {})
        raw_tags = entry.get("tags", "")
        if raw_tags:
            for t in raw_tags.split("|"):
                t = t.strip()
                if t:
                    tags.add(t)
    return sorted(tags)


def _get_resources_from_posts(post_ids: list[str], processed: dict) -> list[dict]:
    """Extract URLs mentioned in post text as pseudo-resources."""
    import re
    resources = []
    seen_urls = set()
    url_pattern = re.compile(r"https?://[^\s,)>\"]+")
    for pid in post_ids:
        chunks = processed.get(pid, [])
        for chunk in chunks:
            urls = url_pattern.findall(chunk.get("text", ""))
            for url in urls:
                if url not in seen_urls:
                    seen_urls.add(url)
                    resources.append({
                        "url": url,
                        "title": "",
                        "type": "link",
                        "post_id": pid,
                    })
    return resources


# ---------------------------------------------------------------------------
# Context building
# ---------------------------------------------------------------------------

def build_context(
    question: str,
    search_results: list[dict],
    manifest: dict,
    processed: dict,
    verbose: bool = False,
) -> dict:
    """Assemble rich knowledge context from search results + metadata.

    Returns a dict with:
        sources          - formatted source text blocks for the LLM prompt
        citations        - structured citation data
        taxonomy_tags    - tags from manifest + DB
        resources        - related URLs / resources
        post_ids         - list of matched post IDs
        raw_results      - original search result dicts
    """
    post_ids = list(dict.fromkeys(r["post_id"] for r in search_results))

    # --- Taxonomy tags ---
    manifest_tags = _get_tags_from_manifest(post_ids, manifest)
    db_data = _sqlite_lookup(post_ids)
    all_tags = sorted(set(manifest_tags + db_data["taxonomy_tags"]))

    # --- Resources ---
    resources = db_data["resources"] or _get_resources_from_posts(post_ids, processed)

    # --- Citations ---
    citations = []
    for r in search_results:
        snippet = r.get("text", "")
        if len(snippet) > 300:
            snippet = snippet[:297] + "..."
        citations.append({
            "post_id": r["post_id"],
            "chunk_id": r.get("chunk_id", ""),
            "author": r.get("author", ""),
            "text_snippet": snippet,
            "score": r.get("score", 0.0),
            "likes": r.get("likes", 0),
            "comments": r.get("comments", 0),
            "platform": r.get("platform", ""),
        })

    # --- Formatted source blocks for the LLM ---
    source_blocks = []
    for i, r in enumerate(search_results, 1):
        meta_entry = manifest.get(r["post_id"], {})
        approx_date = meta_entry.get("approx_date", r.get("time_relative", ""))
        engagement = f"likes={r.get('likes', 0)}, comments={r.get('comments', 0)}, reposts={r.get('reposts', 0)}"
        tags_str = meta_entry.get("tags", "").replace("|", ", ")

        block = (
            f"--- Source {i} ---\n"
            f"Post ID: {r['post_id']}\n"
            f"Author: {r.get('author', 'Unknown')}\n"
            f"Platform: {r.get('platform', '')}\n"
            f"Date: {approx_date}\n"
            f"Engagement: {engagement}\n"
            f"Tags: {tags_str}\n"
            f"Relevance Score: {r.get('score', 0):.3f}\n"
            f"Content:\n{r.get('text', '')}\n"
        )
        source_blocks.append(block)

    return {
        "sources": "\n".join(source_blocks),
        "citations": citations,
        "taxonomy_tags": all_tags,
        "resources": resources,
        "post_ids": post_ids,
        "raw_results": search_results,
    }


# ---------------------------------------------------------------------------
# Confidence estimation
# ---------------------------------------------------------------------------

def _estimate_confidence(search_results: list[dict], question: str) -> str:
    """Estimate answer confidence based on source coverage.

    Returns 'high', 'medium', or 'low'.
    """
    if not search_results:
        return "low"

    scores = [r.get("score", 0) for r in search_results]
    top_score = max(scores)
    high_relevance = sum(1 for s in scores if s >= 0.45)
    medium_relevance = sum(1 for s in scores if s >= 0.30)

    if high_relevance >= 3 and top_score >= 0.50:
        return "high"
    elif medium_relevance >= 2 and top_score >= 0.35:
        return "medium"
    else:
        return "low"


# ---------------------------------------------------------------------------
# AI backend configuration
# ---------------------------------------------------------------------------

LITELLM_PROXY_URL = os.environ.get("LITELLM_PROXY_URL", "http://localhost:8082")
AI_MODEL = os.environ.get("AI_MODEL", "claude-sonnet-4-6")

SYSTEM_PROMPT = """\
You are an expert assistant for Claude Code development practices.
You have access to a curated database of expert knowledge from real practitioners \
who share their workflows, benchmarks, configurations, and hard-won insights.

Answer the user's question based ONLY on the following expert knowledge sources.
If the sources don't fully cover the question, say so honestly and indicate what \
aspects are not covered.

Guidelines:
- For each claim or recommendation, cite the source using [Author, post_id] format.
- Identify patterns that emerge across multiple expert posts.
- When experts disagree or present different approaches, present both perspectives.
- Suggest related resources (URLs, tools, repos) mentioned in the sources.
- Be specific: quote numbers, benchmarks, configuration details when available.
- Do NOT fabricate information not present in the sources.

At the end of your answer, include:
1. A "Key Sources" section listing the most relevant post IDs with brief descriptions.
2. A confidence rating: high (multiple sources agree and directly address the question), \
medium (some relevant sources but incomplete coverage), or low (sources are only \
tangentially related).
"""


def _build_user_message(question: str, context: dict) -> str:
    msg = f"## Expert Knowledge Sources\n\n{context['sources']}\n\n"
    if context["taxonomy_tags"]:
        msg += f"## Related Taxonomy Tags\n{', '.join(context['taxonomy_tags'])}\n\n"
    if context["resources"]:
        lines = [f"- {r['url']} ({r.get('type', 'link')})" for r in context["resources"][:10]]
        msg += "## Related Resources\n" + "\n".join(lines) + "\n\n"
    msg += f"## Question\n{question}"
    return msg


def _call_via_proxy(question: str, context: dict) -> str:
    """Call the local OAuth proxy at LITELLM_PROXY_URL (Anthropic /v1/messages format).

    No API key required — proxy uses OAuth credentials.
    Raises on any failure so callers can fall through to next backend.
    """
    import urllib.request
    import urllib.error

    user_message = _build_user_message(question, context)
    payload = json.dumps({
        "model": AI_MODEL,
        "max_tokens": 2048,
        "system": SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": user_message}],
    }).encode()

    req = urllib.request.Request(
        f"{LITELLM_PROXY_URL}/v1/messages",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read().decode())

    # Anthropic response shape: {"content": [{"type": "text", "text": "..."}], ...}
    content = body.get("content", [])
    if content and isinstance(content, list):
        return content[0].get("text", "")
    raise ValueError(f"Unexpected proxy response shape: {list(body.keys())}")


def _call_via_claude_cli(question: str, context: dict) -> str:
    """Call the claude CLI (OAuth) as a subprocess.

    Uses ~/.local/bin/claude if available, otherwise falls back to PATH.
    Raises on any failure so callers can fall through to next backend.
    """
    import shutil
    import subprocess

    cli = os.path.expanduser("~/.local/bin/claude")
    if not (os.path.isfile(cli) and os.access(cli, os.X_OK)):
        cli = shutil.which("claude")
    if not cli:
        raise RuntimeError("claude CLI not found")

    user_message = _build_user_message(question, context)
    prompt = f"{SYSTEM_PROMPT}\n\n{user_message}"

    env = {**os.environ, "PATH": f"{os.path.expanduser('~/.local/bin')}:{os.environ.get('PATH', '')}"}
    result = subprocess.run(
        [cli, "--print", "--max-tokens", "2048"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=90,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(f"claude CLI exit {result.returncode}: {result.stderr.strip()[:200]}")
    return result.stdout.strip()


def _call_anthropic_direct(question: str, context: dict) -> str:
    """Direct Anthropic API call using ANTHROPIC_API_KEY (legacy fallback).

    Raises RuntimeError when neither the package nor an API key is available.
    """
    try:
        import anthropic
    except ImportError:
        raise RuntimeError("anthropic package not installed and no other backend available")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError("ANTHROPIC_API_KEY not set and no other backend available")

    client = anthropic.Anthropic(api_key=api_key)
    user_message = _build_user_message(question, context)
    response = client.messages.create(
        model=AI_MODEL,
        max_tokens=2048,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )
    return response.content[0].text


def _call_ai(question: str, context: dict) -> str:
    """Try AI backends in priority order:
    1. Local OAuth proxy at LITELLM_PROXY_URL (port 8082 by default)
    2. claude CLI (OAuth, no key needed)
    3. Direct ANTHROPIC_API_KEY (legacy fallback)
    """
    errors = []

    try:
        return _call_via_proxy(question, context)
    except Exception as e:
        errors.append(f"proxy: {e}")

    try:
        return _call_via_claude_cli(question, context)
    except Exception as e:
        errors.append(f"claude CLI: {e}")

    try:
        return _call_anthropic_direct(question, context)
    except Exception as e:
        errors.append(f"anthropic direct: {e}")

    raise RuntimeError("All AI backends failed:\n" + "\n".join(f"  - {e}" for e in errors))


# ---------------------------------------------------------------------------
# Main ask function
# ---------------------------------------------------------------------------

def ask(
    question: str,
    top_k: int = 8,
    verbose: bool = False,
    no_ai: bool = False,
) -> dict:
    """Answer a question using the expertise database as foundational knowledge.

    Args:
        question:  Natural language question.
        top_k:     Number of source chunks to retrieve.
        verbose:   Whether to include full context in output.
        no_ai:     If True, skip the Anthropic API call and return context only.

    Returns:
        {
            "question": str,
            "answer": str,
            "citations": [{"post_id": str, "author": str, "text_snippet": str, "score": float, ...}],
            "related_resources": [{"url": str, "title": str, "type": str}],
            "taxonomy_tags": [str],
            "confidence": str  # "high", "medium", "low" based on source coverage
        }
    """
    # 1. Vector search for relevant chunks
    search_results = search(question, top_k=top_k, min_score=0.15, expand=True)

    if not search_results:
        return {
            "question": question,
            "answer": "No relevant expert knowledge found in the database for this question.",
            "citations": [],
            "related_resources": [],
            "taxonomy_tags": [],
            "confidence": "low",
        }

    # 2. Load metadata sources
    manifest = _load_manifest()
    processed = _load_processed_posts()

    # 3. Build rich context
    context = build_context(question, search_results, manifest, processed, verbose)

    # 4. Estimate confidence
    confidence = _estimate_confidence(search_results, question)

    # 5. Generate answer (or return context only)
    if no_ai:
        answer = (
            "[--no-ai mode: showing retrieved context only]\n\n"
            f"Retrieved {len(search_results)} relevant sources.\n"
            f"Top relevance score: {max(r['score'] for r in search_results):.3f}\n"
            f"Taxonomy tags: {', '.join(context['taxonomy_tags']) or 'none'}\n"
            f"Confidence estimate: {confidence}\n\n"
            "--- Source Summaries ---\n"
        )
        for i, c in enumerate(context["citations"], 1):
            answer += (
                f"\n[{i}] {c['author']}, {c['post_id']} "
                f"(score: {c['score']:.3f}, likes: {c['likes']})\n"
                f"    {c['text_snippet']}\n"
            )
    else:
        try:
            answer = _call_ai(question, context)
        except RuntimeError as e:
            answer = (
                f"[AI unavailable: {e}]\n\n"
                f"Falling back to retrieved context ({len(search_results)} sources).\n\n"
            )
            for i, c in enumerate(context["citations"], 1):
                answer += (
                    f"[{i}] {c['author']}, {c['post_id']} "
                    f"(score: {c['score']:.3f})\n"
                    f"    {c['text_snippet']}\n\n"
                )

    return {
        "question": question,
        "answer": answer,
        "citations": context["citations"],
        "related_resources": context["resources"],
        "taxonomy_tags": context["taxonomy_tags"],
        "confidence": confidence,
    }


# ---------------------------------------------------------------------------
# Terminal formatting
# ---------------------------------------------------------------------------

# ANSI color codes
_BOLD = "\033[1m"
_DIM = "\033[2m"
_CYAN = "\033[36m"
_GREEN = "\033[32m"
_YELLOW = "\033[33m"
_RED = "\033[31m"
_MAGENTA = "\033[35m"
_RESET = "\033[0m"

_CONFIDENCE_COLORS = {
    "high": _GREEN,
    "medium": _YELLOW,
    "low": _RED,
}


def format_answer(result: dict, verbose: bool = False) -> str:
    """Format the answer result for nice terminal output with colors."""
    lines = []

    # Header
    lines.append(f"\n{_BOLD}{_CYAN}Question:{_RESET} {result['question']}")
    lines.append(f"{'=' * 72}")

    # Confidence badge
    conf = result["confidence"]
    conf_color = _CONFIDENCE_COLORS.get(conf, _DIM)
    lines.append(f"{_BOLD}Confidence:{_RESET} {conf_color}{conf.upper()}{_RESET}")

    # Tags
    if result["taxonomy_tags"]:
        tag_str = ", ".join(result["taxonomy_tags"])
        lines.append(f"{_BOLD}Tags:{_RESET} {_DIM}{tag_str}{_RESET}")

    lines.append(f"{'─' * 72}")

    # Answer
    lines.append(f"\n{_BOLD}Answer:{_RESET}\n")
    # Wrap long lines in the answer for readability
    for paragraph in result["answer"].split("\n"):
        if len(paragraph) > 80:
            wrapped = textwrap.fill(paragraph, width=80)
            lines.append(wrapped)
        else:
            lines.append(paragraph)

    # Citations
    if result["citations"]:
        lines.append(f"\n{'─' * 72}")
        lines.append(f"{_BOLD}Sources ({len(result['citations'])}):{_RESET}\n")
        for i, c in enumerate(result["citations"], 1):
            score_pct = int(c["score"] * 100)
            lines.append(
                f"  {_DIM}[{i}]{_RESET} {_MAGENTA}{c['author']}{_RESET} "
                f"({c['post_id']}) "
                f"{_DIM}score={score_pct}% likes={c.get('likes', 0)}{_RESET}"
            )
            if verbose:
                snippet = textwrap.fill(
                    c["text_snippet"],
                    width=72,
                    initial_indent="      ",
                    subsequent_indent="      ",
                )
                lines.append(f"{_DIM}{snippet}{_RESET}")

    # Resources
    if result["related_resources"]:
        lines.append(f"\n{_BOLD}Related Resources:{_RESET}")
        for r in result["related_resources"][:5]:
            title = r.get("title") or r.get("url", "")
            lines.append(f"  {_CYAN}{r['url']}{_RESET}")

    lines.append(f"\n{'=' * 72}\n")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Ask questions grounded in the Claude Code expertise database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            examples:
              python scripts/ask.py "what is the best stack for local AI coding agents?"
              python scripts/ask.py --verbose "how do agent swarms coordinate?"
              python scripts/ask.py --json "worktree patterns for parallel development"
              python scripts/ask.py --no-ai "what hardware for local inference?"
              python scripts/ask.py --top-k 15 "self-improving agents"
        """),
    )
    parser.add_argument("question", help="Natural language question")
    parser.add_argument(
        "--top-k",
        type=int,
        default=8,
        help="Number of source chunks to retrieve (default: 8)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show full context including source snippets",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output as JSON (machine-readable)",
    )
    parser.add_argument(
        "--no-ai",
        action="store_true",
        help="Skip AI generation, just show retrieved context",
    )
    args = parser.parse_args()

    result = ask(
        question=args.question,
        top_k=args.top_k,
        verbose=args.verbose,
        no_ai=args.no_ai,
    )

    if args.json_output:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(format_answer(result, verbose=args.verbose))


if __name__ == "__main__":
    main()
