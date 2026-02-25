#!/usr/bin/env python3
"""
Generate a manifest CSV from raw JSONL data.
Tracks scraping status, content metadata, and provides an overview of the corpus.
"""

import json
import csv
import hashlib
import argparse
from pathlib import Path
from datetime import datetime, timedelta
import re

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"
MANIFEST_PATH = BASE_DIR / "data" / "manifest.csv"


def parse_relative_time(rel_time: str, scraped_date: str) -> str:
    """Convert relative time like '2d', '1w', '3w' to approximate ISO date."""
    if not rel_time:
        return ""

    scraped = datetime.fromisoformat(scraped_date.replace("Z", "+00:00"))

    match = re.match(r"(\d+)(m|h|d|w|mo)", rel_time)
    if not match:
        return ""

    val, unit = int(match.group(1)), match.group(2)
    deltas = {"m": timedelta(minutes=val), "h": timedelta(hours=val),
              "d": timedelta(days=val), "w": timedelta(weeks=val),
              "mo": timedelta(days=val * 30)}

    approx = scraped - deltas.get(unit, timedelta())
    return approx.strftime("%Y-%m-%d")


def content_hash(text: str) -> str:
    """Generate a short content hash for dedup."""
    return hashlib.sha256(text.encode()).hexdigest()[:12]


def generate_manifest(author: str):
    """Generate manifest from a raw JSONL file."""
    raw_path = RAW_DIR / f"{author}.jsonl"
    if not raw_path.exists():
        print(f"Error: {raw_path} not found")
        return

    posts = []
    with open(raw_path, "r") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                post = json.loads(line)
                posts.append(post)
            except json.JSONDecodeError as e:
                print(f"Warning: Skipping malformed line {line_num}: {e}")

    print(f"Loaded {len(posts)} posts from {raw_path.name}")

    # Build manifest rows
    rows = []
    for post in posts:
        text = post.get("text", "")
        approx_date = parse_relative_time(
            post.get("time_relative", ""),
            post.get("scraped_date", datetime.now().isoformat())
        )

        # Extract topic tags via simple keyword matching
        tags = []
        tag_keywords = {
            "claude-code": ["claude code", "claude-code"],
            "local-ai": ["local ai", "local llm", "locally", "on-device", "local model"],
            "hardware": ["gpu", "blackwell", "npu", "macbook", "workstation", "ram", "z8", "zgx"],
            "agents": ["agent", "swarm", "multi-agent", "orchestrat"],
            "open-source": ["open-source", "open source", "open model", "deepseek", "qwen", "olmo", "glm"],
            "quantization": ["quantiz", "nvfp4", "fp8", "gguf", "pruned"],
            "benchmarks": ["benchmark", "tkns/sec", "tokens/sec", "speed"],
            "enterprise": ["enterprise", "codebase", "production"],
            "self-improving": ["self-improv", "genetic", "pareto", "optimize", "feedback loop"],
            "infrastructure": ["kubernetes", "kubectl", "docker", "deploy"],
            "minimax": ["minimax"],
            "opencode": ["opencode", "openclaw"],
        }
        text_lower = text.lower()
        for tag, keywords in tag_keywords.items():
            if any(kw in text_lower for kw in keywords):
                tags.append(tag)

        preview = text.replace("\n", " ")[:80].strip()

        rows.append({
            "id": post.get("id", f"mitko-{len(rows)+1}"),
            "author": post.get("author", "Unknown"),
            "platform": post.get("platform", "linkedin"),
            "approx_date": approx_date,
            "time_relative": post.get("time_relative", ""),
            "scraped_date": post.get("scraped_date", ""),
            "likes": post.get("likes", 0),
            "comments": post.get("comments", 0),
            "reposts": post.get("reposts", 0),
            "text_length": len(text),
            "content_hash": content_hash(text),
            "tags": "|".join(tags),
            "preview": preview,
            "chunk_count": 0,  # Updated after ingestion
            "indexed": False,
        })

    # Write manifest CSV
    fieldnames = list(rows[0].keys()) if rows else []
    with open(MANIFEST_PATH, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Manifest written: {MANIFEST_PATH}")
    print(f"  Total posts: {len(rows)}")
    print(f"  Total text: {sum(r['text_length'] for r in rows):,} characters")
    print(f"  Date range: {rows[-1]['approx_date'] or '?'} → {rows[0]['approx_date'] or 'today'}")
    print(f"  Top tags: {', '.join(sorted(set(t for r in rows for t in r['tags'].split('|') if t), key=lambda x: -sum(1 for r in rows if x in r['tags'])))}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate manifest from raw post data")
    parser.add_argument("--author", default="mitko-vasilev", help="Author slug (filename without .jsonl)")
    args = parser.parse_args()
    generate_manifest(args.author)
