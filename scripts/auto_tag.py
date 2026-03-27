#!/usr/bin/env python3
"""
Auto-tag posts using taxonomy keyword matching.

Scans post text for mentions of taxonomy entries and creates
post_tags relationships with confidence scores.

Usage:
    python scripts/auto_tag.py                    # Tag all untagged posts
    python scripts/auto_tag.py --retag            # Re-tag all posts
    python scripts/auto_tag.py --post mitko-5     # Tag a specific post
    python scripts/auto_tag.py --stats            # Show tagging stats
"""

import json
import re
import argparse
import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "data" / "expertise.db"

# Extended keyword mappings: taxonomy_name -> [keywords that indicate this tag]
TAG_KEYWORDS = {
    # Topics
    "agent-swarms": [
        r"\bswarm\b", r"\bmulti[- ]?agent\b", r"\bagent\s+fleet\b",
        r"\bworkers?\b.*\bagents?\b", r"\b\d+\s+agents?\b", r"\bswarm mode\b"
    ],
    "local-ai": [
        r"\blocal(?:ly)?\s+(?:AI|LLM|model|inference)\b", r"\bon[- ]?device\b",
        r"\bno cloud\b", r"\boffline\b", r"\bself[- ]?hosted\b",
        r"\blocal(?:host)?\b.*\binference\b", r"\bdesktop.*GPU\b"
    ],
    "hardware": [
        r"\bGPU\b", r"\bVRAM\b", r"\bA6000\b", r"\bGB10\b", r"\bZGX\b",
        r"\bBlackwell\b", r"\bStrix\s+Halo\b", r"\b\d+GB\s+(?:RAM|memory)\b",
        r"\bhardware\b", r"\bnano\s+PC\b"
    ],
    "benchmarks": [
        r"\bbenchmark\b", r"\bSWE[- ]?Bench\b", r"\bperformance\b.*\btokens?\b",
        r"\btokens?/sec\b", r"\bTPS\b", r"\blatency\b.*\bP\d+\b"
    ],
    "coding-agents": [
        r"\bcoding\s+agents?\b", r"\bAI\s+coding\b", r"\bagentic.*cod(?:e|ing)\b",
        r"\bcode\s+gen(?:erat)?\b", r"\bautonomous\s+cod(?:e|ing)\b"
    ],
    "context-management": [
        r"\bcontext\s+window\b", r"\b\d+[KkMm]\s+(?:token|context)\b",
        r"\bKV[- ]?cache\b", r"\bcontext\s+(?:limit|length|stuffing)\b"
    ],
    "model-comparison": [
        r"\bvs\.?\b.*\b(?:Opus|Sonnet|Claude|GPT|Qwen|GLM)\b",
        r"\bcompar(?:e|ison|ing)\b.*\bmodel\b", r"\bbetter\s+than\b"
    ],
    "security": [
        r"\bsecurity\b", r"\baudit\b", r"\bvulnerabilit\b",
        r"\bcve\b", r"\bhardening\b"
    ],
    "devops": [
        r"\bsystemd\b", r"\bsystemctl\b", r"\btimer\b.*\bagent\b",
        r"\bCI/?CD\b", r"\bpipeline\b", r"\bdeployment\b"
    ],
    "open-source": [
        r"\bopen[- ]?source\b", r"\bMIT\s+licens\b", r"\bApache\s+2\b",
        r"\bopen[- ]?weight\b"
    ],
    # Techniques
    "worktree-isolation": [
        r"\bworktree\b", r"\bgit\s+worktree\b", r"\bisolated\s+checkout\b"
    ],
    "recursive-lm": [
        r"\brecursive\s+(?:LM|language\s+model)\b", r"\bRLM\b",
        r"\bself[- ]?improv(?:e|ing)\b.*\bagent\b"
    ],
    "token-optimization": [
        r"\btoken\s+optim\b", r"\breducing\s+token\b",
        r"\btoken\s+(?:usage|efficiency|budget)\b"
    ],
    "kv-cache-management": [
        r"\bKV[- ]?cache\b", r"\bcache\s+(?:management|pressure|size)\b"
    ],
    "quantization": [
        r"\bquantiz\b", r"\bFP[48]\b", r"\bINT[48]\b", r"\bNVFP4\b",
        r"\b\d+[- ]?bit\b.*\bmodel\b", r"\bAWQ\b", r"\bGGUF\b"
    ],
    "swarm-coordination": [
        r"\bcoordinat\b.*\bagent\b", r"\borchestrat\b.*\bswarm\b",
        r"\bscheduling\b.*\bagent\b", r"\bdelegat\b"
    ],
    "skill-tuning": [
        r"\bskill\b.*\btun(?:e|ing)\b", r"\bSKILL\b.*\bparam\b",
        r"\boptimize_anything\b"
    ],
    # Tools
    "claude-code": [
        r"\bClaude\s+Code\b", r"\bCC\b\s+(?:switch|agent|swarm)"
    ],
    "opencode": [r"\b[Oo]pencode\b"],
    "vllm": [r"\bvLLM\b"],
    "radicle": [r"\b[Rr]adicle\b", r"\brad\s+sync\b"],
    "bazelcode": [r"\b[Bb]azelcode\b", r"\bBazel\b.*\bagent\b"],
    "openclaw": [r"\b[Oo]pen[Cc]law\b"],
    "dspy": [r"\bDSPy\b"],
    # Concepts
    "self-improving-agents": [
        r"\bself[- ]?improv\b", r"\brecursive(?:ly)?\s+(?:self|improve|optimiz)\b",
        r"\bagent.*\bwrite.*\bown\b"
    ],
    "headless-dev": [
        r"\bheadless\b.*\b(?:dev|workflow|agent)\b", r"\bno\s+(?:VS\s*Code|IDE|UI)\b"
    ],
    "ai-civilization": [
        r"\bAI\s+civiliz\b", r"\bagent.*\bsocial\b", r"\bP2P\s+mesh\b.*\bagent\b"
    ],
    "context-engineering": [
        r"\bcontext\s+engineer\b", r"\bvariable\s+space\b",
        r"\bcontext.*\bpristine\b"
    ],
    "agent-hierarchy": [
        r"\bhierarch\b.*\bagent\b", r"\bcoordinator\b.*\bdomain\b",
        r"\bsub[- ]?agent\b", r"\bworker\s+spawn\b"
    ],
    "proof-bundles": [
        r"\bproof\s+bundle\b", r"\breceipt\b.*\bchange\b",
        r"\bgit\s+diff.*\btest\s+result\b"
    ],
    # Frameworks
    "gepa": [r"\bGEPA\b", r"\bGenetic[- ]?Pareto\b"],
    "swe-bench": [r"\bSWE[- ]?(?:Bench|bench|rebench)\b"],
    "swe-universe": [r"\bSWE[- ]?Universe\b"],
    "rpg-encoder": [r"\bRPG[- ]?Encoder\b"],
    # Patterns
    "scan-audit-report": [
        r"\bscan.*\baudit.*\breport\b", r"\bblast\s+radius\b.*\banalysis\b"
    ],
    "hire-fire-agents": [
        r"\bhire.*\bfire\b.*\bagent\b", r"\bself[- ]?terminat\b",
        r"\bspawn.*\bterminate\b"
    ],
    "variable-space": [
        r"\bvariable\s+space\b", r"\bnot\s+token\s+space\b",
        r"\bPython\s+variable\b.*\bLM\b"
    ],
    "gossip-mesh": [
        r"\bgossip\b.*\bmesh\b", r"\bgossipsub\b", r"\bP2P\s+mesh\b"
    ],
}


def auto_tag_post(conn: sqlite3.Connection, post_id: str, text: str) -> list[tuple[str, float]]:
    """Tag a single post based on keyword matching. Returns [(tag_name, confidence)]."""
    tags_found = []

    for tag_name, patterns in TAG_KEYWORDS.items():
        matches = 0
        for pattern in patterns:
            if re.search(pattern, text, re.IGNORECASE):
                matches += 1

        if matches > 0:
            # Confidence based on how many keyword variants matched
            confidence = min(1.0, 0.5 + (matches * 0.2))
            tags_found.append((tag_name, confidence))

    # Apply tags to database
    for tag_name, confidence in tags_found:
        cursor = conn.execute(
            "SELECT id FROM taxonomy WHERE name = ?", (tag_name,)
        )
        row = cursor.fetchone()
        if row:
            taxonomy_id = row[0]
            conn.execute("""
                INSERT INTO post_tags (post_id, taxonomy_id, confidence, source)
                VALUES (?, ?, ?, 'auto')
                ON CONFLICT (post_id, taxonomy_id) DO UPDATE
                SET confidence = MAX(excluded.confidence, post_tags.confidence)
            """, (post_id, taxonomy_id, confidence))

    return tags_found


def auto_tag_all(conn: sqlite3.Connection, retag: bool = False):
    """Auto-tag all posts."""
    if retag:
        conn.execute("DELETE FROM post_tags WHERE source = 'auto'")

    cursor = conn.execute("""
        SELECT p.id, p.text FROM posts p
        WHERE NOT EXISTS (
            SELECT 1 FROM post_tags pt WHERE pt.post_id = p.id AND pt.source = 'auto'
        ) OR ?
    """, (retag,))

    total_posts = 0
    total_tags = 0

    for row in cursor.fetchall():
        post_id, text = row
        tags = auto_tag_post(conn, post_id, text)
        total_posts += 1
        total_tags += len(tags)
        if tags:
            tag_names = [t[0] for t in tags]
            print(f"  {post_id}: {', '.join(tag_names)}")

    conn.commit()
    print(f"\nTagged {total_posts} posts with {total_tags} total tags")


def show_stats(conn: sqlite3.Connection):
    """Show tagging statistics."""
    cursor = conn.execute("""
        SELECT t.name, t.type, COUNT(pt.post_id) as post_count,
               ROUND(AVG(pt.confidence), 2) as avg_confidence
        FROM taxonomy t
        LEFT JOIN post_tags pt ON t.id = pt.taxonomy_id
        GROUP BY t.id
        ORDER BY post_count DESC
    """)

    print("Tag Distribution:")
    print(f"  {'Tag':<30} {'Type':<12} {'Posts':>6} {'Avg Conf':>10}")
    print(f"  {'-'*30} {'-'*12} {'-'*6} {'-'*10}")
    for row in cursor.fetchall():
        name, type_, count, conf = row
        conf_str = f"{conf:.2f}" if conf else "N/A"
        print(f"  {name:<30} {type_:<12} {count:>6} {conf_str:>10}")


def main():
    parser = argparse.ArgumentParser(description="Auto-tag posts using taxonomy keywords")
    parser.add_argument("--retag", action="store_true", help="Re-tag all posts (clears auto tags)")
    parser.add_argument("--post", type=str, help="Tag a specific post ID")
    parser.add_argument("--stats", action="store_true", help="Show tagging statistics")
    parser.add_argument("--db", type=str, default=str(DB_PATH), help="Database path")
    args = parser.parse_args()

    conn = sqlite3.connect(args.db)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")

    if args.stats:
        show_stats(conn)
    elif args.post:
        cursor = conn.execute("SELECT text FROM posts WHERE id = ?", (args.post,))
        row = cursor.fetchone()
        if row:
            tags = auto_tag_post(conn, args.post, row[0])
            conn.commit()
            print(f"Tags for {args.post}: {', '.join(t[0] for t in tags)}")
        else:
            print(f"Post not found: {args.post}")
    else:
        auto_tag_all(conn, retag=args.retag)

    conn.close()


if __name__ == "__main__":
    main()
