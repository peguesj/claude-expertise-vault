#!/usr/bin/env python3
"""
claude_parse.py - Parse page content using the claude CLI

Usage:
  python scripts/claude_parse.py --content "page text" [--prompt "custom prompt"] [--url "page url"]

Or via stdin:
  echo "page text" | python scripts/claude_parse.py --stdin [--prompt "custom prompt"]

Output:
  JSON to stdout with fields: answer, key_insights, topics, tags, resources
  Errors: JSON to stdout with fields: error, details
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import urllib.error

LITELLM_PROXY_URL = os.environ.get("LITELLM_PROXY_URL", "http://localhost:8082")
AI_MODEL = os.environ.get("AI_MODEL", "claude-sonnet-4-6")

DEFAULT_PROMPT = (
    "Analyze this content about Claude Code and AI development. "
    "Extract: (1) key insights and best practices, (2) main topics covered, "
    "(3) relevant tags/keywords, (4) any mentioned tools, repos, or resources. "
    "Format your response as JSON with fields: answer (2-3 sentence summary), "
    "key_insights (list of strings), topics (list of strings), "
    "tags (list of strings), resources (list of {title, url, type})."
)

EMPTY_RESULT = {
    "answer": "",
    "key_insights": [],
    "topics": [],
    "tags": [],
    "resources": [],
}


def find_claude_cli():
    preferred = os.path.expanduser("~/.local/bin/claude")
    if os.path.isfile(preferred) and os.access(preferred, os.X_OK):
        return preferred
    return shutil.which("claude")


def truncate_at_sentence(text, max_length):
    if len(text) <= max_length:
        return text
    truncated = text[:max_length]
    match = re.search(r"[.!?][^.!?]*$", truncated)
    if match:
        return truncated[: match.start() + 1]
    return truncated


def build_prompt(content, custom_prompt, url):
    if custom_prompt:
        if custom_prompt.rstrip().endswith("."):
            instruction = custom_prompt
        else:
            instruction = f"{custom_prompt} {DEFAULT_PROMPT}"
    else:
        instruction = DEFAULT_PROMPT

    parts = [instruction]
    if url:
        parts.append(f"\nSource URL: {url}")
    parts.append(f"\n\nContent:\n{content}")
    return "".join(parts)


def extract_json(raw):
    stripped = re.sub(r"```(?:json)?\s*", "", raw).replace("```", "").strip()
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", stripped, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            pass
    result = dict(EMPTY_RESULT)
    result["answer"] = raw.strip()
    return result


def _call_via_proxy(full_prompt, timeout=60):
    """Call local OAuth proxy at LITELLM_PROXY_URL (Anthropic /v1/messages format)."""
    payload = json.dumps({
        "model": AI_MODEL,
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": full_prompt}],
    }).encode()
    req = urllib.request.Request(
        f"{LITELLM_PROXY_URL}/v1/messages",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = json.loads(resp.read().decode())
    content = body.get("content", [])
    if content and isinstance(content, list):
        return extract_json(content[0].get("text", ""))
    raise ValueError(f"Unexpected proxy response: {list(body.keys())}")


def _call_via_claude_cli(claude_path, full_prompt, timeout=60):
    """Invoke the claude CLI (OAuth) as a subprocess."""
    env = {
        **os.environ,
        "PATH": f"{os.path.expanduser('~/.local/bin')}:{os.environ.get('PATH', '')}",
    }
    result = subprocess.run(
        [claude_path, "--print", "--max-tokens", "1024"],
        input=full_prompt,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(f"exit={result.returncode}: {result.stderr.strip()[:200]}")
    return extract_json(result.stdout)


def run_claude(full_prompt, timeout=60):
    """Try AI backends in priority order:
    1. Local OAuth proxy at LITELLM_PROXY_URL (port 8082)
    2. claude CLI (OAuth, no key needed)
    """
    errors = []

    try:
        return _call_via_proxy(full_prompt, timeout)
    except Exception as e:
        errors.append(f"proxy: {e}")

    cli = find_claude_cli()
    if cli:
        try:
            return _call_via_claude_cli(cli, full_prompt, timeout)
        except Exception as e:
            errors.append(f"claude CLI: {e}")
    else:
        errors.append("claude CLI: not found")

    return {"error": "All AI backends failed", "details": "; ".join(errors)}


def main():
    parser = argparse.ArgumentParser(description="Parse page content using the claude CLI")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--content", metavar="TEXT", help="Page content to parse")
    group.add_argument("--stdin", action="store_true", help="Read content from stdin")
    parser.add_argument("--prompt", metavar="TEXT", help="Custom prompt prefix (optional)")
    parser.add_argument("--url", metavar="URL", help="Source URL for context (optional)")
    parser.add_argument("--max-length", metavar="INT", type=int, default=8000,
                        help="Truncate content to this many chars (default: 8000)")
    args = parser.parse_args()

    if args.stdin:
        content = sys.stdin.read()
    elif args.content:
        content = args.content
    else:
        print(json.dumps({"error": "no content provided", "details": "Use --content or --stdin"}))
        sys.exit(1)

    content = truncate_at_sentence(content, args.max_length)

    if not content.strip():
        print(json.dumps({"error": "empty content", "details": "Content was empty after reading"}))
        sys.exit(1)

    full_prompt = build_prompt(content, args.prompt, args.url)
    parsed = run_claude(full_prompt)
    print(json.dumps(parsed, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
