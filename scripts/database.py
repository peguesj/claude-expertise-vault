#!/usr/bin/env python3
"""
SQLite resource database for the Claude Expertise Vault.

Provides structured storage for posts, taxonomy, resources, images,
insights, and chunks -- all linked together as a knowledge graph that
complements the FAISS vector index.

Usage:
    python scripts/database.py init              # Create/migrate DB
    python scripts/database.py import            # Import all raw JSONL
    python scripts/database.py discover          # Auto-discover resources in all posts
    python scripts/database.py stats             # Show database stats
    python scripts/database.py taxonomy          # Show taxonomy tree
    python scripts/database.py search --tag agent-swarms --author "Mitko Vasilev"
"""

import argparse
import json
import re
import sqlite3
from pathlib import Path
from datetime import datetime
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
DEFAULT_DB_PATH = DATA_DIR / "expertise.db"

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

SCHEMA_SQL = """
-- Core content
CREATE TABLE IF NOT EXISTS posts (
    id TEXT PRIMARY KEY,
    author TEXT NOT NULL,
    platform TEXT NOT NULL,
    url TEXT,
    text TEXT NOT NULL,
    scraped_date TEXT,
    time_relative TEXT,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    reposts INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Taxonomy system
CREATE TABLE IF NOT EXISTS taxonomy (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL CHECK(type IN ('topic', 'technique', 'tool', 'concept', 'framework', 'pattern')),
    description TEXT,
    parent_id INTEGER REFERENCES taxonomy(id),
    created_at TEXT DEFAULT (datetime('now'))
);

-- Post-taxonomy relationships
CREATE TABLE IF NOT EXISTS post_tags (
    post_id TEXT REFERENCES posts(id),
    taxonomy_id INTEGER REFERENCES taxonomy(id),
    confidence REAL DEFAULT 1.0,
    source TEXT DEFAULT 'manual' CHECK(source IN ('manual', 'auto', 'ai')),
    PRIMARY KEY (post_id, taxonomy_id)
);

-- External resources/links found in or related to posts
CREATE TABLE IF NOT EXISTS resources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT NOT NULL UNIQUE,
    title TEXT,
    type TEXT NOT NULL CHECK(type IN ('github', 'article', 'video', 'tool', 'documentation', 'discussion', 'paper', 'other')),
    description TEXT,
    discovered_in TEXT REFERENCES posts(id),
    verified BOOLEAN DEFAULT 0,
    last_checked TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Resource-taxonomy relationships
CREATE TABLE IF NOT EXISTS resource_tags (
    resource_id INTEGER REFERENCES resources(id),
    taxonomy_id INTEGER REFERENCES taxonomy(id),
    PRIMARY KEY (resource_id, taxonomy_id)
);

-- Post-resource relationships (which posts reference which resources)
CREATE TABLE IF NOT EXISTS post_resources (
    post_id TEXT REFERENCES posts(id),
    resource_id INTEGER REFERENCES resources(id),
    context TEXT,  -- snippet of text around the reference
    PRIMARY KEY (post_id, resource_id)
);

-- Images associated with posts
CREATE TABLE IF NOT EXISTS images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id TEXT REFERENCES posts(id),
    url TEXT,
    local_path TEXT,
    alt_text TEXT,
    downloaded BOOLEAN DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

-- AI-generated insights and summaries
CREATE TABLE IF NOT EXISTS insights (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id TEXT REFERENCES posts(id),
    type TEXT NOT NULL CHECK(type IN ('summary', 'key_takeaway', 'technique', 'recommendation', 'comparison')),
    content TEXT NOT NULL,
    model TEXT DEFAULT 'local',
    created_at TEXT DEFAULT (datetime('now'))
);

-- Chunks (for vector search, linked back to posts)
CREATE TABLE IF NOT EXISTS chunks (
    id TEXT PRIMARY KEY,
    post_id TEXT REFERENCES posts(id),
    chunk_index INTEGER,
    total_chunks INTEGER,
    text TEXT NOT NULL,
    embedding_id INTEGER,  -- index into FAISS
    created_at TEXT DEFAULT (datetime('now'))
);

-- Skill/Authoritative Resource Repositories (ARR/RR)
CREATE TABLE IF NOT EXISTS skill_resource_repositories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL CHECK(type IN ('arr','rr')),
    category TEXT NOT NULL CHECK(category IN ('skills','mcp','api','framework','documentation','prompt_library','tool_collection','other')),
    npm_package TEXT,
    github_url TEXT,
    homepage_url TEXT,
    blog_url TEXT,
    description TEXT,
    tags TEXT DEFAULT '[]',
    skills_count INTEGER DEFAULT 0,
    resource_count INTEGER DEFAULT 0,
    last_scraped TEXT,
    metadata_json TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now'))
);

-- Insights poll log
CREATE TABLE IF NOT EXISTS insights_poll_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    polled_at TEXT DEFAULT (datetime('now')),
    query TEXT,
    count INTEGER DEFAULT 0
);
"""

# Indexes for common query patterns
INDEX_SQL = """
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author);
CREATE INDEX IF NOT EXISTS idx_posts_platform ON posts(platform);
CREATE INDEX IF NOT EXISTS idx_posts_scraped_date ON posts(scraped_date);
CREATE INDEX IF NOT EXISTS idx_taxonomy_type ON taxonomy(type);
CREATE INDEX IF NOT EXISTS idx_taxonomy_name ON taxonomy(name);
CREATE INDEX IF NOT EXISTS idx_post_tags_post ON post_tags(post_id);
CREATE INDEX IF NOT EXISTS idx_post_tags_taxonomy ON post_tags(taxonomy_id);
CREATE INDEX IF NOT EXISTS idx_resources_type ON resources(type);
CREATE INDEX IF NOT EXISTS idx_resources_discovered ON resources(discovered_in);
CREATE INDEX IF NOT EXISTS idx_post_resources_post ON post_resources(post_id);
CREATE INDEX IF NOT EXISTS idx_post_resources_resource ON post_resources(resource_id);
CREATE INDEX IF NOT EXISTS idx_images_post ON images(post_id);
CREATE INDEX IF NOT EXISTS idx_insights_post ON insights(post_id);
CREATE INDEX IF NOT EXISTS idx_insights_type ON insights(type);
CREATE INDEX IF NOT EXISTS idx_chunks_post ON chunks(post_id);
"""

# ---------------------------------------------------------------------------
# Seed taxonomy
# ---------------------------------------------------------------------------

SEED_TAXONOMY = {
    "topic": [
        "agent-swarms", "local-ai", "hardware", "benchmarks",
        "coding-agents", "context-management", "model-comparison",
        "security", "devops", "open-source",
    ],
    "technique": [
        "worktree-isolation", "recursive-lm", "token-optimization",
        "kv-cache-management", "quantization", "swarm-coordination",
        "skill-tuning",
    ],
    "tool": [
        "claude-code", "opencode", "faiss", "vllm", "radicle",
        "bazelcode", "openclaw", "dspy",
    ],
    "concept": [
        "self-improving-agents", "headless-dev", "ai-civilization",
        "context-engineering", "agent-hierarchy", "proof-bundles",
    ],
    "framework": [
        "gepa", "swe-bench", "swe-universe", "rpg-encoder",
    ],
    "pattern": [
        "scan-audit-report", "hire-fire-agents", "variable-space",
        "gossip-mesh",
    ],
}

# ---------------------------------------------------------------------------
# URL extraction helpers
# ---------------------------------------------------------------------------

# Matches http(s) URLs, stopping at typical punctuation/whitespace boundaries
_URL_RE = re.compile(
    r'https?://'
    r'[^\s<>\"\'\)\]\},;]+'
)

# Heuristics for classifying a URL into a resource type
_URL_TYPE_RULES = [
    (re.compile(r'github\.com|gitlab\.com|bitbucket\.org'), 'github'),
    (re.compile(r'youtube\.com|youtu\.be|vimeo\.com'), 'video'),
    (re.compile(r'arxiv\.org|papers\.'), 'paper'),
    (re.compile(r'docs\.|documentation|readme|wiki'), 'documentation'),
    (re.compile(r'reddit\.com|news\.ycombinator|forum|discuss'), 'discussion'),
    (re.compile(r'medium\.com|substack\.com|blog\.|dev\.to'), 'article'),
]


def extract_urls_from_text(text: str) -> list[str]:
    """Extract URLs from post text using regex.

    Returns a deduplicated list of URLs found in the text, with trailing
    punctuation stripped.
    """
    urls = _URL_RE.findall(text)
    cleaned = []
    seen = set()
    for url in urls:
        # Strip trailing punctuation that regex may have captured
        url = url.rstrip(".,;:!?)")
        if url not in seen:
            seen.add(url)
            cleaned.append(url)
    return cleaned


def _classify_url(url: str) -> str:
    """Classify a URL into a resource type based on domain heuristics."""
    url_lower = url.lower()
    for pattern, rtype in _URL_TYPE_RULES:
        if pattern.search(url_lower):
            return rtype
    return 'other'


def _extract_context(text: str, url: str, window: int = 120) -> str:
    """Extract a snippet of text surrounding a URL for context."""
    idx = text.find(url)
    if idx == -1:
        return ""
    start = max(0, idx - window)
    end = min(len(text), idx + len(url) + window)
    snippet = text[start:end].strip()
    if start > 0:
        snippet = "..." + snippet
    if end < len(text):
        snippet = snippet + "..."
    return snippet


# ---------------------------------------------------------------------------
# Database functions
# ---------------------------------------------------------------------------

def init_db(db_path: Optional[str] = None) -> sqlite3.Connection:
    """Create/open the SQLite database with WAL mode and foreign keys.

    Args:
        db_path: Path to the database file. Defaults to data/expertise.db.

    Returns:
        sqlite3.Connection with row_factory set to sqlite3.Row.
    """
    path = Path(db_path) if db_path else DEFAULT_DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")

    # Create tables
    conn.executescript(SCHEMA_SQL)
    conn.executescript(INDEX_SQL)
    conn.commit()

    return conn


def _seed_taxonomy(conn: sqlite3.Connection) -> int:
    """Insert seed taxonomy entries. Skips duplicates. Returns count inserted."""
    inserted = 0
    for tax_type, names in SEED_TAXONOMY.items():
        for name in names:
            try:
                conn.execute(
                    "INSERT INTO taxonomy (name, type) VALUES (?, ?)",
                    (name, tax_type),
                )
                inserted += 1
            except sqlite3.IntegrityError:
                pass  # already exists
    conn.commit()
    return inserted


def import_from_jsonl(conn: sqlite3.Connection, jsonl_path: str | Path) -> int:
    """Import raw JSONL posts into the posts table.

    Performs an upsert -- existing posts (by id) are updated with fresh data.

    Args:
        conn: Active database connection.
        jsonl_path: Path to the raw JSONL file.

    Returns:
        Number of posts imported.
    """
    path = Path(jsonl_path)
    if not path.exists():
        raise FileNotFoundError(f"JSONL file not found: {path}")

    count = 0
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                post = json.loads(line)
            except json.JSONDecodeError:
                continue

            conn.execute(
                """INSERT INTO posts (id, author, platform, url, text,
                   scraped_date, time_relative, likes, comments, reposts, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                   ON CONFLICT(id) DO UPDATE SET
                       author=excluded.author,
                       platform=excluded.platform,
                       url=excluded.url,
                       text=excluded.text,
                       scraped_date=excluded.scraped_date,
                       time_relative=excluded.time_relative,
                       likes=excluded.likes,
                       comments=excluded.comments,
                       reposts=excluded.reposts,
                       updated_at=datetime('now')
                """,
                (
                    post["id"],
                    post.get("author", ""),
                    post.get("platform", ""),
                    post.get("url", ""),
                    post.get("text", ""),
                    post.get("scraped_date", ""),
                    post.get("time_relative", ""),
                    post.get("likes", 0),
                    post.get("comments", 0),
                    post.get("reposts", 0),
                ),
            )
            count += 1

    conn.commit()
    return count


def get_post(conn: sqlite3.Connection, post_id: str) -> Optional[dict]:
    """Return a post with all its tags, resources, and images.

    Args:
        conn: Active database connection.
        post_id: The post ID.

    Returns:
        Dict with post data and nested tags, resources, images, insights,
        or None if not found.
    """
    row = conn.execute("SELECT * FROM posts WHERE id = ?", (post_id,)).fetchone()
    if not row:
        return None

    post = dict(row)

    # Tags
    post["tags"] = [
        dict(r) for r in conn.execute(
            """SELECT t.name, t.type, pt.confidence, pt.source
               FROM post_tags pt
               JOIN taxonomy t ON t.id = pt.taxonomy_id
               WHERE pt.post_id = ?""",
            (post_id,),
        ).fetchall()
    ]

    # Resources
    post["resources"] = [
        dict(r) for r in conn.execute(
            """SELECT r.id, r.url, r.title, r.type, r.description, pr.context
               FROM post_resources pr
               JOIN resources r ON r.id = pr.resource_id
               WHERE pr.post_id = ?""",
            (post_id,),
        ).fetchall()
    ]

    # Images
    post["images"] = [
        dict(r) for r in conn.execute(
            "SELECT * FROM images WHERE post_id = ?", (post_id,)
        ).fetchall()
    ]

    # Insights
    post["insights"] = [
        dict(r) for r in conn.execute(
            "SELECT * FROM insights WHERE post_id = ?", (post_id,)
        ).fetchall()
    ]

    return post


def search_posts(
    conn: sqlite3.Connection,
    *,
    author: Optional[str] = None,
    platform: Optional[str] = None,
    tag: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    text_contains: Optional[str] = None,
    min_likes: Optional[int] = None,
    limit: int = 50,
) -> list[dict]:
    """Filter posts by various criteria.

    All filters are optional and combined with AND logic.

    Args:
        conn: Active database connection.
        author: Filter by author name (case-insensitive LIKE match).
        platform: Filter by platform (exact match).
        tag: Filter by taxonomy tag name.
        date_from: Minimum scraped_date (ISO 8601).
        date_to: Maximum scraped_date (ISO 8601).
        text_contains: Substring search in post text (case-insensitive).
        min_likes: Minimum number of likes.
        limit: Maximum number of results (default 50).

    Returns:
        List of post dicts matching the filters.
    """
    clauses = []
    params: list = []

    if author:
        clauses.append("p.author LIKE ?")
        params.append(f"%{author}%")

    if platform:
        clauses.append("p.platform = ?")
        params.append(platform)

    if tag:
        clauses.append(
            """p.id IN (
                SELECT pt.post_id FROM post_tags pt
                JOIN taxonomy t ON t.id = pt.taxonomy_id
                WHERE t.name = ?
            )"""
        )
        params.append(tag)

    if date_from:
        clauses.append("p.scraped_date >= ?")
        params.append(date_from)

    if date_to:
        clauses.append("p.scraped_date <= ?")
        params.append(date_to)

    if text_contains:
        clauses.append("p.text LIKE ?")
        params.append(f"%{text_contains}%")

    if min_likes is not None:
        clauses.append("p.likes >= ?")
        params.append(min_likes)

    where = " AND ".join(clauses) if clauses else "1=1"
    params.append(limit)

    rows = conn.execute(
        f"""SELECT p.* FROM posts p
            WHERE {where}
            ORDER BY p.likes DESC, p.scraped_date DESC
            LIMIT ?""",
        params,
    ).fetchall()

    return [dict(r) for r in rows]


def add_taxonomy(
    conn: sqlite3.Connection,
    name: str,
    type: str,
    description: Optional[str] = None,
    parent_id: Optional[int] = None,
) -> int:
    """Create a taxonomy entry.

    Args:
        conn: Active database connection.
        name: Unique taxonomy name.
        type: One of topic, technique, tool, concept, framework, pattern.
        description: Optional description.
        parent_id: Optional parent taxonomy ID for hierarchy.

    Returns:
        The ID of the new taxonomy entry.
    """
    cursor = conn.execute(
        "INSERT INTO taxonomy (name, type, description, parent_id) VALUES (?, ?, ?, ?)",
        (name, type, description, parent_id),
    )
    conn.commit()
    return cursor.lastrowid


def tag_post(
    conn: sqlite3.Connection,
    post_id: str,
    taxonomy_id: int,
    confidence: float = 1.0,
    source: str = "manual",
) -> None:
    """Tag a post with a taxonomy entry.

    Args:
        conn: Active database connection.
        post_id: The post ID.
        taxonomy_id: The taxonomy entry ID.
        confidence: Confidence score (0.0 to 1.0, default 1.0).
        source: Tag source -- manual, auto, or ai.
    """
    conn.execute(
        """INSERT INTO post_tags (post_id, taxonomy_id, confidence, source)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(post_id, taxonomy_id) DO UPDATE SET
               confidence=excluded.confidence,
               source=excluded.source""",
        (post_id, taxonomy_id, confidence, source),
    )
    conn.commit()


def add_resource(
    conn: sqlite3.Connection,
    url: str,
    title: Optional[str],
    type: str,
    description: Optional[str] = None,
    discovered_in: Optional[str] = None,
) -> int:
    """Add an external resource.

    Args:
        conn: Active database connection.
        url: The resource URL (must be unique).
        title: Optional resource title.
        type: Resource type (github, article, video, tool, documentation,
              discussion, paper, other).
        description: Optional description.
        discovered_in: Post ID where the resource was found.

    Returns:
        The ID of the new or existing resource.
    """
    try:
        cursor = conn.execute(
            """INSERT INTO resources (url, title, type, description, discovered_in)
               VALUES (?, ?, ?, ?, ?)""",
            (url, title, type, description, discovered_in),
        )
        conn.commit()
        return cursor.lastrowid
    except sqlite3.IntegrityError:
        # URL already exists; return existing ID
        row = conn.execute(
            "SELECT id FROM resources WHERE url = ?", (url,)
        ).fetchone()
        return row["id"]


def link_post_resource(
    conn: sqlite3.Connection,
    post_id: str,
    resource_id: int,
    context: Optional[str] = None,
) -> None:
    """Link a post to a resource.

    Args:
        conn: Active database connection.
        post_id: The post ID.
        resource_id: The resource ID.
        context: Optional text snippet providing context for the link.
    """
    conn.execute(
        """INSERT INTO post_resources (post_id, resource_id, context)
           VALUES (?, ?, ?)
           ON CONFLICT(post_id, resource_id) DO UPDATE SET
               context=excluded.context""",
        (post_id, resource_id, context),
    )
    conn.commit()


def auto_discover_resources(conn: sqlite3.Connection, post_id: str) -> int:
    """Extract URLs from a post's text and create resource entries.

    Automatically classifies each URL by domain and links it to the post.

    Args:
        conn: Active database connection.
        post_id: The post ID to scan for URLs.

    Returns:
        Number of resources discovered.
    """
    row = conn.execute(
        "SELECT text FROM posts WHERE id = ?", (post_id,)
    ).fetchone()
    if not row:
        return 0

    text = row["text"]
    urls = extract_urls_from_text(text)
    count = 0

    for url in urls:
        rtype = _classify_url(url)
        context = _extract_context(text, url)
        resource_id = add_resource(
            conn, url=url, title=None, type=rtype,
            description=None, discovered_in=post_id,
        )
        link_post_resource(conn, post_id, resource_id, context)
        count += 1

    return count


def get_taxonomy_tree(conn: sqlite3.Connection) -> dict:
    """Return the full taxonomy as a nested dict grouped by type.

    Returns:
        Dict keyed by taxonomy type, each containing a list of entries.
        Entries with parent_id are nested under their parent.
    """
    rows = conn.execute(
        "SELECT id, name, type, description, parent_id FROM taxonomy ORDER BY type, name"
    ).fetchall()

    # Build a lookup and tree
    by_id: dict[int, dict] = {}
    tree: dict[str, list[dict]] = {}

    for row in rows:
        entry = dict(row)
        entry["children"] = []
        by_id[entry["id"]] = entry

    # Attach children to parents
    for entry in by_id.values():
        parent_id = entry.get("parent_id")
        if parent_id and parent_id in by_id:
            by_id[parent_id]["children"].append(entry)
        else:
            tax_type = entry["type"]
            if tax_type not in tree:
                tree[tax_type] = []
            tree[tax_type].append(entry)

    return tree


def get_post_graph(conn: sqlite3.Connection, post_id: str) -> Optional[dict]:
    """Return a post with all linked resources, tags, and insights.

    This is the full knowledge graph view for a single post.

    Args:
        conn: Active database connection.
        post_id: The post ID.

    Returns:
        Dict with post data, tags, resources (with their own tags),
        images, insights, and chunk info. None if not found.
    """
    post = get_post(conn, post_id)
    if not post:
        return None

    # Enrich resources with their taxonomy tags
    for resource in post.get("resources", []):
        resource["tags"] = [
            dict(r) for r in conn.execute(
                """SELECT t.name, t.type
                   FROM resource_tags rt
                   JOIN taxonomy t ON t.id = rt.taxonomy_id
                   WHERE rt.resource_id = ?""",
                (resource["id"],),
            ).fetchall()
        ]

    # Chunks
    post["chunks"] = [
        dict(r) for r in conn.execute(
            "SELECT id, chunk_index, total_chunks, embedding_id FROM chunks WHERE post_id = ?",
            (post_id,),
        ).fetchall()
    ]

    return post


def stats(conn: sqlite3.Connection) -> dict:
    """Return database statistics summary.

    Returns:
        Dict with counts for each table and additional metrics.
    """
    tables = [
        "posts", "taxonomy", "post_tags", "resources",
        "resource_tags", "post_resources", "images", "insights", "chunks",
    ]
    counts = {}
    for table in tables:
        row = conn.execute(f"SELECT COUNT(*) as c FROM {table}").fetchone()
        counts[table] = row["c"]

    # Extra stats
    row = conn.execute(
        "SELECT COUNT(DISTINCT author) as c FROM posts"
    ).fetchone()
    counts["unique_authors"] = row["c"]

    row = conn.execute(
        "SELECT COUNT(DISTINCT platform) as c FROM posts"
    ).fetchone()
    counts["unique_platforms"] = row["c"]

    row = conn.execute(
        "SELECT SUM(likes) as total FROM posts"
    ).fetchone()
    counts["total_likes"] = row["total"] or 0

    row = conn.execute(
        "SELECT AVG(likes) as avg FROM posts"
    ).fetchone()
    counts["avg_likes"] = round(row["avg"], 1) if row["avg"] else 0

    # Taxonomy breakdown
    tax_breakdown = {}
    for row in conn.execute(
        "SELECT type, COUNT(*) as c FROM taxonomy GROUP BY type ORDER BY type"
    ).fetchall():
        tax_breakdown[row["type"]] = row["c"]
    counts["taxonomy_by_type"] = tax_breakdown

    # Top tags
    top_tags = [
        {"name": r["name"], "count": r["c"]}
        for r in conn.execute(
            """SELECT t.name, COUNT(*) as c
               FROM post_tags pt
               JOIN taxonomy t ON t.id = pt.taxonomy_id
               GROUP BY t.id
               ORDER BY c DESC
               LIMIT 10"""
        ).fetchall()
    ]
    counts["top_tags"] = top_tags

    # Resource type breakdown
    res_breakdown = {}
    for row in conn.execute(
        "SELECT type, COUNT(*) as c FROM resources GROUP BY type ORDER BY c DESC"
    ).fetchall():
        res_breakdown[row["type"]] = row["c"]
    counts["resources_by_type"] = res_breakdown

    return counts


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _format_taxonomy_tree(tree: dict) -> str:
    """Format taxonomy tree for terminal display."""
    lines = []
    for tax_type, entries in sorted(tree.items()):
        lines.append(f"\n  [{tax_type.upper()}] ({len(entries)} entries)")
        for entry in entries:
            desc = f" -- {entry['description']}" if entry.get("description") else ""
            lines.append(f"    - {entry['name']}{desc}")
            for child in entry.get("children", []):
                cdesc = f" -- {child['description']}" if child.get("description") else ""
                lines.append(f"      - {child['name']}{cdesc}")
    return "\n".join(lines)


def _format_stats(s: dict) -> str:
    """Format stats dict for terminal display."""
    lines = [
        "\n  Claude Expertise Vault -- Database Stats",
        "  " + "=" * 48,
        "",
        f"  Posts:            {s['posts']:>6}",
        f"  Unique authors:   {s['unique_authors']:>6}",
        f"  Unique platforms: {s['unique_platforms']:>6}",
        f"  Total likes:      {s['total_likes']:>6}",
        f"  Avg likes/post:   {s['avg_likes']:>6}",
        "",
        f"  Taxonomy entries: {s['taxonomy']:>6}",
        f"  Post tags:        {s['post_tags']:>6}",
        f"  Resources:        {s['resources']:>6}",
        f"  Resource tags:    {s['resource_tags']:>6}",
        f"  Post-resource:    {s['post_resources']:>6}",
        f"  Images:           {s['images']:>6}",
        f"  Insights:         {s['insights']:>6}",
        f"  Chunks:           {s['chunks']:>6}",
    ]

    if s.get("taxonomy_by_type"):
        lines.append("")
        lines.append("  Taxonomy breakdown:")
        for ttype, count in sorted(s["taxonomy_by_type"].items()):
            lines.append(f"    {ttype:<12} {count:>4}")

    if s.get("resources_by_type"):
        lines.append("")
        lines.append("  Resources by type:")
        for rtype, count in s["resources_by_type"].items():
            lines.append(f"    {rtype:<16} {count:>4}")

    if s.get("top_tags"):
        lines.append("")
        lines.append("  Top tags:")
        for t in s["top_tags"]:
            lines.append(f"    {t['name']:<28} {t['count']:>4} posts")

    lines.append("")
    return "\n".join(lines)


def _format_post(post: dict, verbose: bool = False) -> str:
    """Format a single post for terminal display."""
    text_preview = post["text"][:200].replace("\n", " ")
    if len(post["text"]) > 200:
        text_preview += "..."

    lines = [
        f"  [{post['id']}] {post['author']} | {post['platform']} | "
        f"{post.get('time_relative', '?')} ago",
        f"    Likes: {post['likes']}  Comments: {post['comments']}  "
        f"Reposts: {post['reposts']}",
        f"    {text_preview}",
    ]

    if verbose and post.get("tags"):
        tag_names = [t["name"] for t in post["tags"]]
        lines.append(f"    Tags: {', '.join(tag_names)}")

    if verbose and post.get("resources"):
        lines.append(f"    Resources: {len(post['resources'])} linked")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# ARR / RR (Skill Resource Repositories)
# ---------------------------------------------------------------------------

SEED_ARRS = [
    {
        "name": "claude-code-templates",
        "slug": "claude-code-templates",
        "type": "arr",
        "category": "skills",
        "npm_package": "claude-code-templates",
        "github_url": "https://github.com/davila7/claude-code-templates",
        "homepage_url": "https://www.aitmpl.com/skills",
        "blog_url": "https://www.aitmpl.com/blog/index.html",
        "description": "Community-maintained collection of Claude Code skill templates with npm install support",
        "tags": '["claude-code","skills","templates","ai-coding"]',
    },
]


def insert_arr(conn: sqlite3.Connection, record: dict) -> bool:
    """Insert or ignore an ARR/RR entry. Returns True if inserted."""
    tags = record.get("tags", "[]")
    if isinstance(tags, list):
        import json as _json
        tags = _json.dumps(tags)
    try:
        conn.execute(
            """INSERT OR IGNORE INTO skill_resource_repositories
               (name, slug, type, category, npm_package, github_url, homepage_url,
                blog_url, description, tags, skills_count, resource_count, metadata_json)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                record.get("name"), record.get("slug"),
                record.get("type", "rr"), record.get("category", "other"),
                record.get("npm_package"), record.get("github_url"),
                record.get("homepage_url"), record.get("blog_url"),
                record.get("description", ""), tags,
                record.get("skills_count", 0), record.get("resource_count", 0),
                record.get("metadata_json", "{}"),
            ),
        )
        conn.commit()
        return conn.execute("SELECT changes()").fetchone()[0] > 0
    except sqlite3.Error:
        return False


def list_arrs(
    conn: sqlite3.Connection,
    category: Optional[str] = None,
    type_filter: Optional[str] = None,
) -> list:
    """Return all ARR/RR entries, optionally filtered."""
    query = "SELECT * FROM skill_resource_repositories"
    params: list = []
    clauses = []
    if category:
        clauses.append("category=?")
        params.append(category)
    if type_filter:
        clauses.append("type=?")
        params.append(type_filter)
    if clauses:
        query += " WHERE " + " AND ".join(clauses)
    query += " ORDER BY type DESC, name"
    rows = conn.execute(query, params).fetchall()
    return [dict(r) for r in rows]


def seed_arrs(conn: sqlite3.Connection) -> int:
    """Insert SEED_ARRS entries (skip duplicates). Returns count inserted."""
    return sum(1 for r in SEED_ARRS if insert_arr(conn, r))


def cmd_arr(args: argparse.Namespace) -> None:
    """List ARR/RR (skill resource repositories)."""
    conn = init_db(args.db)
    arrs = list_arrs(conn, category=getattr(args, "category", None),
                     type_filter=getattr(args, "type_filter", None))
    conn.close()
    if not arrs:
        print("  No ARR/RR entries found. Run 'init' to seed defaults.")
    else:
        import json as _json
        print(f"\n  ARR/RR Repositories ({len(arrs)} entries)")
        print("  " + "=" * 72)
        for e in arrs:
            tags = _json.loads(e.get("tags") or "[]")
            print(f"  [{e['type'].upper()}] {e['name']} ({e['category']})")
            if e.get("npm_package"):
                print(f"        npm: {e['npm_package']}")
            if e.get("github_url"):
                print(f"        github: {e['github_url']}")
            if e.get("homepage_url"):
                print(f"        web: {e['homepage_url']}")
            if tags:
                print(f"        tags: {', '.join(tags)}")
            print()


def cmd_init(args: argparse.Namespace) -> None:
    """Create/migrate the database and seed taxonomy."""
    conn = init_db(args.db)
    inserted = _seed_taxonomy(conn)
    arr_seeded = seed_arrs(conn)
    total = conn.execute("SELECT COUNT(*) as c FROM taxonomy").fetchone()["c"]
    print(f"  Database initialized: {args.db or DEFAULT_DB_PATH}")
    print(f"  Taxonomy: {inserted} new entries seeded ({total} total)")
    print(f"  ARR/RR: {arr_seeded} entries seeded")
    conn.close()


def cmd_import(args: argparse.Namespace) -> None:
    """Import all raw JSONL files into the database."""
    conn = init_db(args.db)

    total = 0
    jsonl_files = sorted(RAW_DIR.glob("*.jsonl"))

    if not jsonl_files:
        print(f"  No JSONL files found in {RAW_DIR}")
        conn.close()
        return

    for jsonl_path in jsonl_files:
        count = import_from_jsonl(conn, jsonl_path)
        print(f"  Imported {count} posts from {jsonl_path.name}")
        total += count

    print(f"  Total: {total} posts imported")
    conn.close()


def cmd_discover(args: argparse.Namespace) -> None:
    """Auto-discover resources (URLs) in all posts."""
    conn = init_db(args.db)

    rows = conn.execute("SELECT id FROM posts").fetchall()
    total_resources = 0

    for row in rows:
        count = auto_discover_resources(conn, row["id"])
        if count > 0:
            print(f"  {row['id']}: {count} URLs discovered")
            total_resources += count

    print(f"  Total: {total_resources} resources discovered across {len(rows)} posts")
    conn.close()


def cmd_stats(args: argparse.Namespace) -> None:
    """Show database statistics."""
    conn = init_db(args.db)
    s = stats(conn)
    print(_format_stats(s))
    conn.close()


def cmd_taxonomy(args: argparse.Namespace) -> None:
    """Show the taxonomy tree."""
    conn = init_db(args.db)
    tree = get_taxonomy_tree(conn)
    total = conn.execute("SELECT COUNT(*) as c FROM taxonomy").fetchone()["c"]
    print(f"\n  Taxonomy ({total} entries)")
    print("  " + "=" * 48)
    print(_format_taxonomy_tree(tree))
    print()
    conn.close()


def cmd_search(args: argparse.Namespace) -> None:
    """Search posts with filters."""
    conn = init_db(args.db)

    results = search_posts(
        conn,
        author=args.author,
        platform=args.platform,
        tag=args.tag,
        date_from=args.date_from,
        date_to=args.date_to,
        text_contains=args.text,
        min_likes=args.min_likes,
        limit=args.limit,
    )

    if args.json:
        print(json.dumps(results, indent=2, default=str))
    elif not results:
        print("  No posts found matching filters.")
    else:
        print(f"\n  Found {len(results)} posts\n")
        for post in results:
            # Fetch tags for display
            enriched = get_post(conn, post["id"])
            print(_format_post(enriched or post, verbose=True))
            print()

    conn.close()


def main():
    parser = argparse.ArgumentParser(
        description="Claude Expertise Vault -- SQLite resource database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  python scripts/database.py init
  python scripts/database.py import
  python scripts/database.py discover
  python scripts/database.py stats
  python scripts/database.py taxonomy
  python scripts/database.py search --tag agent-swarms
  python scripts/database.py search --author "Mitko Vasilev" --min-likes 200
  python scripts/database.py search --text "worktree" --json
        """,
    )
    parser.add_argument(
        "--db", type=str, default=None,
        help=f"Database path (default: {DEFAULT_DB_PATH})",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # init
    subparsers.add_parser("init", help="Create/migrate database and seed taxonomy")

    # import
    subparsers.add_parser("import", help="Import all raw JSONL files into the database")

    # discover
    subparsers.add_parser("discover", help="Auto-discover resources (URLs) in all posts")

    # stats
    subparsers.add_parser("stats", help="Show database statistics")

    # taxonomy
    subparsers.add_parser("taxonomy", help="Show taxonomy tree")

    # search
    search_parser = subparsers.add_parser("search", help="Search posts with filters")
    search_parser.add_argument("--author", type=str, help="Filter by author name")
    search_parser.add_argument("--platform", type=str, help="Filter by platform")
    search_parser.add_argument("--tag", type=str, help="Filter by taxonomy tag name")
    search_parser.add_argument("--date-from", type=str, help="Minimum date (ISO 8601)")
    search_parser.add_argument("--date-to", type=str, help="Maximum date (ISO 8601)")
    search_parser.add_argument("--text", type=str, help="Text substring search")
    search_parser.add_argument("--min-likes", type=int, help="Minimum likes")
    search_parser.add_argument("--limit", type=int, default=50, help="Max results (default 50)")
    search_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # arr
    arr_parser = subparsers.add_parser("arr", help="List ARR/RR skill resource repositories")
    arr_parser.add_argument("--category", type=str)
    arr_parser.add_argument("--type", dest="type_filter", choices=["arr", "rr"])

    args = parser.parse_args()

    commands = {
        "init": cmd_init,
        "import": cmd_import,
        "discover": cmd_discover,
        "stats": cmd_stats,
        "taxonomy": cmd_taxonomy,
        "search": cmd_search,
        "arr": cmd_arr,
    }

    commands[args.command](args)


if __name__ == "__main__":
    main()
