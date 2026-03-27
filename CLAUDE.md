# Claude Code Expertise Vault

## Project Purpose
Catalogue, vectorize, and make searchable the expert knowledge shared by Claude Code practitioners. This is an AI-powered knowledge base built from real-world Claude Code usage patterns, tips, and workflows shared by experts on social media. Supports AI-grounded Q&A, taxonomy-based navigation, resource tracking, and browser-based content scraping.

## Architecture

### Directory Structure
```
.
├── CLAUDE.md                    # This file — project overview & conventions
├── .claude/
│   ├── settings.json            # Claude Code project settings
│   └── commands/                # Custom slash commands
│       ├── search.md            # Semantic search the knowledge base
│       └── ask.md               # AI Q&A grounded in expertise DB
├── data/
│   ├── raw/                     # Raw scraped posts (JSONL per expert)
│   │   └── mitko-vasilev.jsonl
│   ├── processed/               # Cleaned & chunked for embedding
│   │   └── mitko-vasilev.jsonl
│   ├── images/                  # Downloaded post images
│   │   └── {author}/{post_id}/  # Per-post image directories
│   └── expertise.db             # SQLite resource database
├── vectorstore/
│   ├── index.bin                # FAISS vector index
│   └── metadata.json            # Chunk metadata mapping
├── scripts/
│   ├── ingest.py                # Parse raw → processed chunks
│   ├── embed.py                 # Generate embeddings & build index
│   ├── search.py                # Semantic vector search with query expansion
│   ├── ask.py                   # AI Q&A powered by Anthropic API
│   ├── database.py              # SQLite resource DB with taxonomy
│   ├── scrape_images.py         # Download images from posts
│   ├── manifest.py              # Generate data manifest CSV
│   ├── run.sh                   # Launch all services
│   └── userscript/              # Browser extension
│       └── claude-expertise-scraper.user.js  # Tampermonkey scraper
├── expertise_api/               # Phoenix/Elixir backend
│   ├── mix.exs                  # Elixir dependencies
│   ├── config/                  # Phoenix configuration
│   ├── lib/
│   │   ├── expertise_api/
│   │   │   ├── search.ex        # Python bridge (calls search.py)
│   │   │   ├── ask.ex           # Python bridge (calls ask.py)
│   │   │   ├── pipeline.ex      # Data pipeline orchestration
│   │   │   ├── ingest.ex        # Post ingestion from userscript
│   │   │   └── database.ex      # SQLite taxonomy/resource bridge
│   │   └── expertise_api_web/
│   │       ├── router.ex         # Routes (LiveView + JSON API)
│   │       ├── controllers/
│   │       │   └── search_controller.ex  # All API endpoints
│   │       ├── live/
│   │       │   └── search_live.ex  # LiveView search UI
│   │       └── plugs/
│   │           └── cors.ex       # CORS for Swift app + userscript
│   └── priv/static/
├── ExpertiseApp/                # SwiftUI macOS menubar app
│   ├── Package.swift            # Swift Package Manager config
│   └── ExpertiseApp/
│       ├── ExpertiseApp.swift    # @main App + MenuBarExtra
│       ├── SearchView.swift      # Search UI + toolbar + stats panel
│       ├── SearchViewModel.swift # State + scan/import/auto-scan
│       ├── APIClient.swift       # HTTP client (search, ask, pipeline)
│       ├── SearchResult.swift    # Codable models (results, stats, pipeline)
│       ├── WebViewContainer.swift # WKWebView wrapper
│       └── Info.plist            # LSUIElement (menubar-only)
└── requirements.txt             # Python dependencies
```

### Four-Tier System
1. **Python Layer** — FAISS vector search, SQLite database, AI Q&A, image scraping
2. **Phoenix/Elixir Layer** — Web API + LiveView UI, pipeline orchestration, ingestion
3. **SwiftUI Layer** — Native macOS menubar app with scan/import/auto-scan controls
4. **Browser Layer** — Tampermonkey userscript for scraping any webpage into the system

### Vectorization Approach
- **Embedding Model**: `sentence-transformers/all-MiniLM-L6-v2` (384-dim, fast, local, no API keys needed)
- **Vector Store**: FAISS (Facebook AI Similarity Search) — lightweight, file-based, no server needed
- **Semantic Expansion**: Natural language queries expanded with domain-specific synonyms for better recall
- **Chunking Strategy**: Each post is one chunk. Long posts (>512 tokens) are split at paragraph boundaries with overlap.
- **Metadata**: Each chunk stores author, date, URL, tags, engagement metrics, images, and original text.

### Resource Database (SQLite)
- **Posts**: Core content with full metadata
- **Taxonomy**: Hierarchical classification (topics, techniques, tools, concepts, frameworks, patterns)
- **Resources**: External links/repos discovered in posts with type classification
- **Images**: Downloaded media with local paths
- **Insights**: AI-generated summaries and key takeaways
- **Chunks**: Vector search chunks linked back to source posts
- **Referential integrity**: Foreign keys + auto-discovery of resources from post text

### Data Schema (per post)
```json
{
  "id": "string",
  "author": "string",
  "date": "ISO8601",
  "url": "string",
  "text": "string",
  "media": ["image_urls"],
  "links": ["discovered_urls"],
  "likes": 0,
  "comments": 0,
  "reposts": 0,
  "tags": ["claude-code", "tips"],
  "platform": "x|linkedin|youtube|github|blog|other"
}
```

## Conventions
- Raw data is always preserved — never modify files in `data/raw/` (except to add media fields)
- Processed data is reproducible from raw via `scripts/ingest.py`
- All Python scripts use argparse for CLI usage
- Search results return top-k with similarity scores and source attribution
- Taxonomy is seeded on `database.py init` and grows via auto-tagging
- The userscript POSTs to `/api/ingest` when the server is running, or copies JSONL to clipboard

## API Contract

### Search & Query
- `GET /api/search?q=<query>&top_k=5&min_score=0.2` — Semantic vector search
- `GET /api/ask?q=<question>&top_k=8` — AI-powered Q&A with citations
- `GET /` — Phoenix LiveView web UI

### Data Management
- `GET /api/health` — Health check
- `GET /api/stats` — Database statistics
- `GET /api/taxonomy` — Full taxonomy tree
- `GET /api/resources?type=github&tag=agent-swarms` — Browse resources
- `POST /api/ingest` — Ingest posts from userscript (`{posts: [...]}`)
- `POST /api/scan` — Scan for new content & media URLs
- `POST /api/import` — Run full pipeline (ingest + embed)
- `POST /api/scrape-images` — Download images from posts

## Usage

### Quick Start (all services)
```bash
./scripts/run.sh
```

### Individual Components
```bash
# Python: Install dependencies
pip install -r requirements.txt

# Database: Initialize with taxonomy
python scripts/database.py init
python scripts/database.py import
python scripts/database.py discover

# Python: Ingest, embed, search
python scripts/ingest.py --author mitko-vasilev
python scripts/embed.py
python scripts/search.py "how to use claude code hooks"

# AI Q&A (requires ANTHROPIC_API_KEY)
python scripts/ask.py "best stack for agentic programming?"

# Images
python scripts/scrape_images.py --author mitko-vasilev

# Phoenix: Start API server
cd expertise_api && mix deps.get && mix phx.server

# Swift: Build and run menubar app
cd ExpertiseApp && swift build && .build/debug/ExpertiseApp
```

### Claude Code Slash Commands
- `/search <query>` — Semantic search with query expansion
- `/ask <question>` — AI-powered Q&A grounded in expertise DB

### Browser Userscript
Install `scripts/userscript/claude-expertise-scraper.user.js` in Tampermonkey.
Works on LinkedIn, X/Twitter, GitHub, YouTube, HN, Reddit, blogs.
Ctrl+Shift+E to export current page.

## Experts Tracked
1. **Mitko Vasilev** — Local AI, agent swarms, Claude Code expert (115 posts)

## Project Management
- **Plane Project**: CEV (Claude Expertise Vault) on plane.lgtm.build
- **Project ID**: 957bc85a-62f4-4f56-90cb-4778a3050d47
