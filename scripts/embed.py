#!/usr/bin/env python3
"""
Generate embeddings from processed chunks and build a FAISS index.

Uses sentence-transformers/all-MiniLM-L6-v2 (384-dim, fast, local).
"""

import json
import numpy as np
import argparse
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
PROCESSED_DIR = BASE_DIR / "data" / "processed"
VECTOR_DIR = BASE_DIR / "vectorstore"


def build_index():
    """Load all processed chunks, embed them, and build FAISS index."""
    from sentence_transformers import SentenceTransformer
    import faiss

    VECTOR_DIR.mkdir(parents=True, exist_ok=True)

    # Load all processed chunks
    chunks = []
    for jsonl_path in sorted(PROCESSED_DIR.glob("*.jsonl")):
        with open(jsonl_path, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    chunks.append(json.loads(line))

    if not chunks:
        print("No chunks found. Run ingest.py first.")
        return

    print(f"Loading model...")
    model = SentenceTransformer("all-MiniLM-L6-v2")

    print(f"Embedding {len(chunks)} chunks...")
    texts = [c["text"] for c in chunks]
    embeddings = model.encode(texts, show_progress_bar=True, batch_size=32)
    embeddings = np.array(embeddings, dtype="float32")

    # Normalize for cosine similarity
    faiss.normalize_L2(embeddings)

    # Build FAISS index (Inner Product on normalized vectors = cosine similarity)
    dim = embeddings.shape[1]
    index = faiss.IndexFlatIP(dim)
    index.add(embeddings)

    # Save index
    index_path = VECTOR_DIR / "index.bin"
    faiss.write_index(index, str(index_path))

    # Save metadata
    metadata = []
    for c in chunks:
        metadata.append({
            "chunk_id": c["chunk_id"],
            "post_id": c["post_id"],
            "author": c["author"],
            "platform": c["platform"],
            "time_relative": c.get("time_relative", ""),
            "likes": c.get("likes", 0),
            "comments": c.get("comments", 0),
            "reposts": c.get("reposts", 0),
            "chunk_index": c.get("chunk_index", 0),
            "total_chunks": c.get("total_chunks", 1),
            "text": c["text"],
        })

    meta_path = VECTOR_DIR / "metadata.json"
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"\nIndex built:")
    print(f"  Vectors: {index.ntotal}")
    print(f"  Dimensions: {dim}")
    print(f"  Index: {index_path}")
    print(f"  Metadata: {meta_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build FAISS vector index from processed chunks")
    args = parser.parse_args()
    build_index()
