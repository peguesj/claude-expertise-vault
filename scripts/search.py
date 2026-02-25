#!/usr/bin/env python3
"""
Search the vector store for relevant expert knowledge.

Usage:
    python scripts/search.py "how to run claude code with local models"
    python scripts/search.py --top-k 10 "agent orchestration patterns"
"""

import json
import numpy as np
import argparse
import textwrap
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
VECTOR_DIR = BASE_DIR / "vectorstore"


def search(query: str, top_k: int = 5, min_score: float = 0.2):
    """Search the vector index and return top-k results."""
    from sentence_transformers import SentenceTransformer
    import faiss

    index_path = VECTOR_DIR / "index.bin"
    meta_path = VECTOR_DIR / "metadata.json"

    if not index_path.exists():
        print("Error: No index found. Run embed.py first.")
        return []

    # Load index and metadata
    index = faiss.read_index(str(index_path))
    with open(meta_path, "r") as f:
        metadata = json.load(f)

    # Embed query
    model = SentenceTransformer("all-MiniLM-L6-v2")
    query_vec = model.encode([query])
    query_vec = np.array(query_vec, dtype="float32")
    faiss.normalize_L2(query_vec)

    # Search
    scores, indices = index.search(query_vec, top_k)

    results = []
    for score, idx in zip(scores[0], indices[0]):
        if idx < 0 or score < min_score:
            continue
        meta = metadata[idx]
        results.append({
            "score": float(score),
            **meta,
        })

    return results


def main():
    parser = argparse.ArgumentParser(description="Search the expertise knowledge base")
    parser.add_argument("query", help="Search query")
    parser.add_argument("--top-k", type=int, default=5, help="Number of results")
    parser.add_argument("--min-score", type=float, default=0.2, help="Minimum similarity score")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    results = search(args.query, args.top_k, args.min_score)

    if args.json:
        print(json.dumps(results, indent=2))
        return

    if not results:
        print("No results found.")
        return

    print(f"\n🔍 Results for: \"{args.query}\"\n")
    print("=" * 70)

    for i, r in enumerate(results, 1):
        score_bar = "█" * int(r["score"] * 20) + "░" * (20 - int(r["score"] * 20))
        engagement = f"👍 {r['likes']} 💬 {r['comments']} 🔄 {r['reposts']}"

        print(f"\n#{i}  [{score_bar}] {r['score']:.3f}")
        print(f"    📝 {r['post_id']} (chunk {r['chunk_index']+1}/{r['total_chunks']})")
        print(f"    👤 {r['author']} | {r.get('time_relative', '?')} ago | {engagement}")
        print(f"    ─{'─' * 60}")

        # Wrap text nicely
        wrapped = textwrap.fill(r["text"], width=66, initial_indent="    ", subsequent_indent="    ")
        # Show first 400 chars
        if len(wrapped) > 400:
            wrapped = wrapped[:400] + "..."
        print(wrapped)

    print(f"\n{'=' * 70}")
    print(f"Showing {len(results)} of {args.top_k} requested results\n")


if __name__ == "__main__":
    main()
