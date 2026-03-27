#!/usr/bin/env python3
"""
Ingest raw JSONL posts into processed chunks for embedding.

Chunking strategy:
- Each post becomes one chunk if <= 512 tokens (~2000 chars)
- Longer posts are split at paragraph boundaries with 1-sentence overlap
- Each chunk carries full metadata for attribution
"""

import json
import argparse
import re
from pathlib import Path
from datetime import datetime

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"
PROCESSED_DIR = BASE_DIR / "data" / "processed"
IMAGES_DIR = BASE_DIR / "data" / "images"


def _get_image_paths(post_id: str, author: str) -> list[str]:
    """Look up local image paths for a post from the media mapping."""
    mapping_path = IMAGES_DIR / author / "media_mapping.json"
    if not mapping_path.exists():
        return []
    try:
        with open(mapping_path, "r") as f:
            mapping = json.load(f)
        return mapping.get(post_id, [])
    except (json.JSONDecodeError, OSError):
        return []

# Approximate token count: ~4 chars per token for English
CHAR_LIMIT = 2000  # ~500 tokens


def split_into_chunks(text: str, max_chars: int = CHAR_LIMIT) -> list[str]:
    """Split text into chunks at paragraph boundaries."""
    if len(text) <= max_chars:
        return [text]

    paragraphs = text.split("\n\n")
    chunks = []
    current = ""

    for para in paragraphs:
        if len(current) + len(para) + 2 <= max_chars:
            current = current + "\n\n" + para if current else para
        else:
            if current:
                chunks.append(current.strip())
            # If single paragraph exceeds limit, split by sentences
            if len(para) > max_chars:
                sentences = re.split(r'(?<=[.!?])\s+', para)
                current = ""
                for sent in sentences:
                    if len(current) + len(sent) + 1 <= max_chars:
                        current = current + " " + sent if current else sent
                    else:
                        if current:
                            chunks.append(current.strip())
                        current = sent
            else:
                current = para

    if current.strip():
        chunks.append(current.strip())

    return chunks if chunks else [text[:max_chars]]


def ingest(author: str):
    """Process raw JSONL into chunked JSONL for embedding."""
    raw_path = RAW_DIR / f"{author}.jsonl"
    out_path = PROCESSED_DIR / f"{author}.jsonl"

    if not raw_path.exists():
        print(f"Error: {raw_path} not found")
        return

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    total_posts = 0
    total_chunks = 0

    with open(raw_path, "r") as fin, open(out_path, "w") as fout:
        for line in fin:
            line = line.strip()
            if not line:
                continue

            try:
                post = json.loads(line)
            except json.JSONDecodeError:
                continue

            total_posts += 1
            text = post.get("text", "").strip()

            # Remove the recurring signature line
            text = re.sub(
                r'\n*Make sure you own your AI\. AI in the cloud is not aligned with you.*$',
                '', text, flags=re.DOTALL
            ).strip()
            text = re.sub(r'\n*…more\s*$', '', text).strip()

            if not text:
                continue

            chunks = split_into_chunks(text)

            # Collect image paths from media mapping if available
            images = _get_image_paths(post.get("id", ""), author)

            for ci, chunk in enumerate(chunks):
                record = {
                    "chunk_id": f"{post['id']}_c{ci}",
                    "post_id": post["id"],
                    "author": post.get("author", ""),
                    "platform": post.get("platform", ""),
                    "url": post.get("url", ""),
                    "time_relative": post.get("time_relative", ""),
                    "scraped_date": post.get("scraped_date", ""),
                    "likes": post.get("likes", 0),
                    "comments": post.get("comments", 0),
                    "reposts": post.get("reposts", 0),
                    "chunk_index": ci,
                    "total_chunks": len(chunks),
                    "text": chunk,
                }
                if images:
                    record["images"] = images
                fout.write(json.dumps(record) + "\n")
                total_chunks += 1

    print(f"Ingested: {raw_path.name}")
    print(f"  Posts: {total_posts}")
    print(f"  Chunks: {total_chunks}")
    print(f"  Output: {out_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest raw posts into chunks")
    parser.add_argument("--author", default="mitko-vasilev", help="Author slug")
    args = parser.parse_args()
    ingest(args.author)
