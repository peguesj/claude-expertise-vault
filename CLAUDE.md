# Claude Code Expertise Vault

> **Version**: see `VERSION` file — current: 4.1.0

## Project Purpose
Catalogue, vectorize, and make searchable the expert knowledge shared by Claude Code practitioners. An AI-powered knowledge base built from real-world usage patterns, tips, and workflows shared by experts on social media. Supports AI-grounded Q&A, taxonomy navigation, resource tracking, authority-based periodic sync, and browser-based content scraping.

## Architecture

### Five-Layer System
1. **Python Layer** — FAISS vector search, SQLite database, AI Q&A, image scraping, authority fetching
2. **Phoenix/Elixir Layer** — Web API + LiveView UI, pipeline orchestration, ingestion, AuthoritySyncer GenServer
3. **SwiftUI Layer** — Native macOS menubar app: search, start page, authorities panel (⌘⇧U), analytics
4. **Browser Layer (Userscript)** — Tampermonkey v4.1.0: scrape any page, authority auto-detect, 30-min cooldown
5. **Browser Layer (Extension)** — Chrome/Edge extension v4.1.0: popup search, options, background sync

### Directory Structure
```
.
├── VERSION                      # Canonical version — single source of truth
├── CLAUDE.md                    # This file — project overview & conventions
├── openapi.yaml                 # Full OpenAPI 3.1.0 spec (API v4.1.0)
├── prd.json                     # Formation history (fmt-cev-001 through fmt-cev-003)
├── .claude/
│   ├── settings.json            # Claude Code project settings
│   ├── hooks/                   # Pre/post tool use hooks
│   └── commands/
│       ├── search.md            # /search slash command
│       └── ask.md               # /ask slash command
├── data/
│   ├── raw/                     # Raw scraped posts (JSONL per authority)
│   │   ├── mitko-vasilev.jsonl  # 115 posts
│   │   ├── webpro255.jsonl      # 51 posts
│   │   ├── owl-listener.jsonl   # 19 posts
│   │   ├── vanguart.jsonl       # 6 posts
│   │   ├── aitmpl.jsonl         # 2 posts
│   │   ├── anthropic-docs.jsonl # 16 pages
│   │   └── unknown.jsonl        # 23 posts
│   ├── processed/               # Cleaned & chunked for embedding
│   └── expertise.db             # SQLite: posts, taxonomy, authorities, analytics
├── vectorstore/
│   ├── index.bin                # FAISS vector index (rebuilt on each import)
│   └── metadata.json            # Chunk metadata mapping
├── scripts/
│   ├── ingest.py                # Parse raw → processed chunks
│   ├── embed.py                 # Generate embeddings & build FAISS index
│   ├── search.py                # Semantic vector search with query expansion
│   ├── ask.py                   # AI Q&A powered by Anthropic API
│   ├── database.py              # SQLite: posts, taxonomy, authorities, analytics
│   ├── fetch.py                 # Authority fetchers: GitHub API, RSS, HTML, browser-only
│   ├── scrape_images.py         # Download images from posts
│   ├── auto_tag.py              # Auto-taxonomy tagging via Anthropic API
│   ├── claude_parse.py          # Claude-format content parser
│   ├── run.sh                   # Launch all services
│   └── userscript/
│       ├── claude-expertise-scraper.user.js  # Tampermonkey scraper v4.1.0
│       └── README.md
├── extension/                   # Chrome/Edge extension v4.1.0
│   ├── manifest.json            # Manifest V3
│   ├── popup.html / popup.js / popup.css
│   ├── options.html / options.js / options.css
│   ├── background.js            # Service worker
│   └── icons/
├── sources/                     # Scraped Anthropic documentation (markdown)
│   ├── INDEX.md
│   ├── api/                     # Tool use, models, getting started
│   ├── blog/                    # Recent announcements
│   ├── claude-code/             # Hooks, memory, agents, CLI ref, settings, MCP
│   ├── mcp/                     # MCP specification + introduction
│   └── model-spec/              # Claude model spec
├── expertise_api/               # Phoenix/Elixir backend (v1.0.0)
│   ├── mix.exs
│   ├── config/
│   ├── lib/
│   │   ├── expertise_api/
│   │   │   ├── search.ex            # Python bridge: search.py
│   │   │   ├── ask.ex               # Python bridge: ask.py
│   │   │   ├── pipeline.ex          # Pipeline orchestration
│   │   │   ├── ingest.ex            # Post ingestion from userscript/extension
│   │   │   ├── database.ex          # SQLite taxonomy/resource bridge
│   │   │   ├── analytics.ex         # Search analytics, preferences, recommendations
│   │   │   ├── authorities.ex       # Authority CRUD + Python bridge
│   │   │   └── authority_syncer.ex  # GenServer: check due every 5 min
│   │   └── expertise_api_web/
│   │       ├── router.ex
│   │       ├── controllers/
│   │       │   ├── search_controller.ex
│   │       │   ├── analytics_controller.ex
│   │       │   ├── authority_controller.ex
│   │       │   └── docs_controller.ex
│   │       ├── live/search_live.ex  # LiveView UI (liquid glass)
│   │       └── plugs/cors.ex
│   ├── AGENTS.md                # Agent development guide
│   └── README.md
├── ExpertiseApp/                # SwiftUI macOS menubar app
│   ├── Package.swift
│   └── ExpertiseApp/
│       ├── ExpertiseApp.swift       # @main App + MenuBarExtra
│       ├── SearchView.swift         # Search, start page, authorities panel
│       ├── SearchViewModel.swift    # State management
│       ├── APIClient.swift          # HTTP client: all API endpoints
│       ├── SearchResult.swift       # Codable models
│       ├── WebViewContainer.swift   # WKWebView wrapper
│       └── ClaudeMenuBarLabel.swift # Menubar icon
└── requirements.txt             # Python dependencies
```

### Vectorization
- **Embedding Model**: `sentence-transformers/all-MiniLM-L6-v2` (384-dim, local, no API keys)
- **Vector Store**: FAISS — file-based, no server required
- **Semantic Expansion**: Queries expanded with domain-specific synonyms for better recall
- **Chunking**: One chunk per post; posts >512 tokens split at paragraph boundaries with overlap

### Resource Database (SQLite)
- **posts** — full metadata per post
- **taxonomy** — hierarchical classification (topics, techniques, tools, concepts, frameworks, patterns)
- **authorities** — tracked expert sources with credibility scoring, scrape config, sync scheduling
- **resources** — external links/repos discovered in posts
- **images** — downloaded media with local paths
- **insights** — AI-generated summaries
- **chunks** — vector search chunks linked to source posts
- **search_events / interactions / preferences** — analytics tables

### Authority System
Authorities are tracked expert sources that are periodically re-fetched for new content.

- **Platform adapters** (`scripts/fetch.py`):
  - `github` — GitHub REST API (repos + events)
  - `rss` — feedparser + stdlib fallback
  - `html` — urllib-based HTML scraping
  - `browser-only` — returns instructions (used for LinkedIn; userscript handles sync on page visit)
- **AuthoritySyncer** (`expertise_api/lib/expertise_api/authority_syncer.ex`) — GenServer checks due authorities every 5 min, ingests new content, broadcasts via PubSub
- **Userscript auto-detect** — on authority page load, auto-POSTs to `/api/ingest` with 30-min cooldown

Seeded authorities: `mitko-vasilev` (LinkedIn/browser-only), `owl-listener` (GitHub), `webpro255` (GitHub), `aitmpl` (HTML)

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
- Taxonomy seeded on `database.py init` and grows via auto-tagging
- Userscript and extension both POST to `/api/ingest`; userscript also copies JSONL to clipboard as fallback
- Canonical version is in the `VERSION` file at the repo root

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
- `POST /api/ingest` — Ingest posts (`{posts: [...]}`)
- `POST /api/scan` — Scan for new content & media URLs
- `POST /api/import` — Run full pipeline (ingest + embed)
- `POST /api/scrape-images` — Download images from posts

### Analytics
- `POST /api/analytics/search` — Log search event
- `POST /api/analytics/interaction` — Log result interaction
- `GET /api/analytics/top-queries?limit=20` — Most searched terms
- `GET /api/analytics/recommendations` — Personalized post recommendations
- `GET /api/analytics/preferences` — User tag weight profile
- `GET /api/analytics/insights-feed?limit=20` — Trending topics, highlights, stats

### Authorities
- `GET /api/authorities` — List all authorities
- `POST /api/authorities` — Register new authority
- `GET /api/authorities/:slug` — Authority detail
- `POST /api/authorities/:slug/sync` — Trigger immediate sync
- `GET /api/authorities/due` — Authorities due for sync
- `GET /api/authorities/syncer/status` — GenServer health
- `POST /api/authorities/recalculate-credibility` — Refresh credibility scores

### Developer Docs
- `GET /docs` — Scalar API reference UI
- `GET /api/openapi.yaml` — OpenAPI 3.1.0 spec

## Usage

### Quick Start
```bash
./scripts/run.sh
```

### Individual Components
```bash
# Python dependencies
pip install -r requirements.txt

# Database: init, import, discover
python scripts/database.py init
python scripts/database.py import
python scripts/database.py discover

# Authority management
python scripts/database.py authority-list
python scripts/fetch.py --slug owl-listener
python scripts/fetch.py --sync-all-due

# Ingest, embed, search
python scripts/ingest.py --author mitko-vasilev
python scripts/embed.py
python scripts/search.py "how to use claude code hooks"

# AI Q&A (requires ANTHROPIC_API_KEY)
python scripts/ask.py "best stack for agentic programming?"

# Phoenix backend (port 8645)
cd expertise_api && mix deps.get && mix phx.server

# Swift menubar app
cd ExpertiseApp && swift build && .build/debug/ExpertiseApp
```

### Claude Code Slash Commands
- `/search <query>` — Semantic search with query expansion
- `/ask <question>` — AI-powered Q&A grounded in expertise DB

### Browser Userscript (v4.1.0)
Install `scripts/userscript/claude-expertise-scraper.user.js` in Tampermonkey.
- Works on LinkedIn, X/Twitter, GitHub, YouTube, HN, Reddit, blogs
- `Ctrl+Shift+E` to export current page
- Auto-detects authority pages and syncs on visit (30-min cooldown)

### Chrome Extension (v4.1.0)
Load `extension/` as an unpacked extension in Chrome/Edge.
- Popup: search, ask, recent queries
- Options: server URL, API key config

## Experts Tracked (Vault: 232+ raw posts)
| Authority | Platform | Posts | Adapter |
|-----------|----------|-------|---------|
| mitko-vasilev | LinkedIn | 115 | browser-only |
| webpro255 | GitHub | 51 | github |
| unknown | various | 23 | — |
| owl-listener | GitHub | 19 | github |
| anthropic-docs | web | 16 | html |
| vanguart | various | 6 | — |
| aitmpl | web | 2 | html |

## Project Management
- **Plane Project**: CEV (Claude Expertise Vault) on plane.lgtm.build
- **Project ID**: 957bc85a-62f4-4f56-90cb-4778a3050d47
- **GitHub**: https://github.com/peguesj/claude-expertise-vault

## Formation History
| Formation | Description | Status |
|-----------|-------------|--------|
| fmt-cev-001 | Initial commit — 4-layer stack | Complete |
| fmt-cev-002 | ARR/insights design, Mermaid, expertise skill, auto-taxonomy | Complete |
| fmt-cev-003 | Liquid glass UI, analytics, VIKI autosync, extension v4, userscript v4, authority system | Complete |
