#!/usr/bin/env python3
"""
Search the vector store for relevant expert knowledge.

Supports semantic phrasing: natural language queries are expanded with
synonyms and related terms to improve recall against the embedding space.

Usage:
    python scripts/search.py "how to run claude code with local models"
    python scripts/search.py --top-k 10 "agent orchestration patterns"
    python scripts/search.py --expand "best way to make agents work together"
"""

import json
import numpy as np
import argparse
import textwrap
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
VECTOR_DIR = BASE_DIR / "vectorstore"

# Semantic expansion: map common natural language phrases to technical terms
# that better match the embedding space of our expert content
SEMANTIC_EXPANSIONS = {
    # Agent patterns
    r"\bagents?\s+work(?:ing)?\s+together\b": "agent swarm coordination multi-agent orchestration",
    r"\bparallel\s+(?:agents?|workers?|tasks?)\b": "concurrent agents swarm parallel workers",
    r"\bagent\s+(?:fleet|army|team)\b": "agent swarm multi-agent coordination",
    r"\bself[- ]improv": "recursive self-improving agents optimize skill",
    # Local AI / hardware
    r"\blocal(?:ly)?\s+(?:run|host|deploy|inference)\b": "local AI inference on-device GPU desktop",
    r"\bno\s+cloud\b": "local offline on-device self-hosted",
    r"\brun\s+(?:on|at)\s+home\b": "local desktop GPU inference self-hosted",
    r"\bhardware\s+(?:setup|config|build)\b": "GPU VRAM desktop workstation hardware",
    r"\bsmall\s+(?:gpu|device|computer)\b": "nano GPU edge device compact hardware ZGX",
    # Claude Code specific
    r"\bhooks?\b": "claude code hooks prehook posthook",
    r"\bworktree": "git worktree parallel branches isolated checkout",
    r"\bcontext\s+(?:window|limit|management)\b": "context window tokens management stuffing",
    r"\bCLAUDE\.md\b": "CLAUDE.md instructions configuration project setup",
    # Performance
    r"\bfast(?:er|est)?\b": "speed throughput tokens per second performance",
    r"\bbenchmark": "benchmark performance comparison evaluation SWE-bench",
    r"\btoken\s+(?:speed|rate|throughput)\b": "tokens per second throughput TPS generation speed",
    # Models
    r"\bopen\s*source\s+model": "open source model local weights Qwen GLM MiniMax",
    r"\bwhich\s+model\b": "model comparison benchmark evaluation",
    r"\bbest\s+model\b": "model benchmark comparison top performing",
    # Workflows
    r"\bsetup\b": "configuration setup install workflow getting started",
    r"\bsecurity\b": "security audit vulnerability codebase scanning",
    r"\bcodebase\s+(?:analysis|review|audit)\b": "codebase analysis review security audit large repository",
}


def expand_query(query: str) -> str:
    """Expand a natural language query with related technical terms.

    Uses regex pattern matching to detect semantic intent and append
    relevant terms that improve vector similarity matching.
    """
    expansions = []
    query_lower = query.lower()

    for pattern, expansion in SEMANTIC_EXPANSIONS.items():
        if re.search(pattern, query_lower):
            expansions.append(expansion)

    if not expansions:
        return query

    # Combine original query with expansions, weighting original higher
    return f"{query} {' '.join(expansions)}"


def search(query: str, top_k: int = 5, min_score: float = 0.2, expand: bool = True):
    """Search the vector index and return top-k results.

    Args:
        query: The search query (natural language or keywords)
        top_k: Number of results to return
        min_score: Minimum cosine similarity threshold
        expand: Whether to apply semantic query expansion
    """
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

    # Optionally expand query for better semantic matching
    search_query = expand_query(query) if expand else query

    # Embed query
    model = SentenceTransformer("all-MiniLM-L6-v2")

    # Multi-query strategy: search with both original and expanded queries,
    # then merge results for better recall
    queries_to_search = [search_query]
    if expand and search_query != query:
        queries_to_search.append(query)

    seen_ids = set()
    all_results = []

    for q in queries_to_search:
        query_vec = model.encode([q])
        query_vec = np.array(query_vec, dtype="float32")
        faiss.normalize_L2(query_vec)

        scores, indices = index.search(query_vec, top_k)

        for score, idx in zip(scores[0], indices[0]):
            if idx < 0 or score < min_score:
                continue
            meta = metadata[idx]
            chunk_id = meta.get("chunk_id", str(idx))
            if chunk_id not in seen_ids:
                seen_ids.add(chunk_id)
                result = {"score": float(score), **meta}
                # Include image paths if available
                if "images" in meta and meta["images"]:
                    result["images"] = meta["images"]
                all_results.append(result)

    # Sort by score descending and limit to top_k
    all_results.sort(key=lambda r: r["score"], reverse=True)
    return all_results[:top_k]


def main():
    parser = argparse.ArgumentParser(description="Search the expertise knowledge base")
    parser.add_argument("query", help="Search query (supports natural language)")
    parser.add_argument("--top-k", type=int, default=5, help="Number of results")
    parser.add_argument("--min-score", type=float, default=0.2, help="Minimum similarity score")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--no-expand", action="store_true", help="Disable semantic query expansion")
    args = parser.parse_args()

    results = search(args.query, args.top_k, args.min_score, expand=not args.no_expand)

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
