# Claude Code Expertise Vault

## Project Purpose
Catalogue, vectorize, and make searchable the expert knowledge shared by Claude Code practitioners. This is a knowledge base built from real-world Claude Code usage patterns, tips, and workflows shared by experts on social media.

## Architecture

### Directory Structure
```
.
├── CLAUDE.md                    # This file — project overview & conventions
├── .claude/
│   ├── settings.json            # Claude Code project settings
│   └── commands/                # Custom slash commands
│       └── search.md            # Search the knowledge base
├── data/
│   ├── raw/                     # Raw scraped posts (JSON per expert)
│   │   └── mitko-vasilev.jsonl
│   └── processed/               # Cleaned & chunked for embedding
│       └── mitko-vasilev.jsonl
├── vectorstore/
│   ├── index.bin                # FAISS vector index
│   └── metadata.json            # Chunk metadata mapping
├── scripts/
│   ├── ingest.py                # Parse raw → processed chunks
│   ├── embed.py                 # Generate embeddings & build index
│   ├── search.py                # Query the vector store
│   ├── manifest.py              # Generate data manifest CSV
│   └── run.sh                   # Launch all services
├── expertise_api/               # Phoenix/Elixir backend
│   ├── mix.exs                  # Elixir dependencies
│   ├── config/                  # Phoenix configuration
│   ├── lib/
│   │   ├── expertise_api/
│   │   │   └── search.ex        # Python bridge (calls search.py)
│   │   └── expertise_api_web/
│   │       ├── router.ex         # Routes (LiveView + JSON API)
│   │       ├── controllers/
│   │       │   └── search_controller.ex  # GET /api/search, /api/health
│   │       ├── live/
│   │       │   └── search_live.ex  # LiveView search UI
│   │       └── plugs/
│   │           └── cors.ex       # CORS for Swift app
│   └── priv/static/
├── ExpertiseApp/                # SwiftUI macOS menubar app
│   ├── Package.swift            # Swift Package Manager config
│   └── ExpertiseApp/
│       ├── ExpertiseApp.swift    # @main App + MenuBarExtra
│       ├── SearchView.swift      # Search UI + ResultCard
│       ├── SearchViewModel.swift # State management + debounced search
│       ├── APIClient.swift       # HTTP client for Phoenix API
│       ├── SearchResult.swift    # Codable API response models
│       ├── WebViewContainer.swift # WKWebView wrapper
│       └── Info.plist            # LSUIElement (menubar-only)
└── requirements.txt             # Python dependencies
```

### Vectorization Approach
- **Embedding Model**: `sentence-transformers/all-MiniLM-L6-v2` (384-dim, fast, local, no API keys needed)
- **Vector Store**: FAISS (Facebook AI Similarity Search) — lightweight, file-based, no server needed
- **Chunking Strategy**: Each post is one chunk. Long posts (>512 tokens) are split at paragraph boundaries with overlap.
- **Metadata**: Each chunk stores author, date, URL, tags, engagement metrics, and original text.

### Data Schema (per post)
```json
{
  "id": "string",
  "author": "string",
  "date": "ISO8601",
  "url": "string",
  "text": "string",
  "media": ["urls"],
  "likes": 0,
  "comments": 0,
  "reposts": 0,
  "tags": ["claude-code", "tips"],
  "platform": "x|linkedin|youtube"
}
```

## Conventions
- Raw data is always preserved — never modify files in `data/raw/`
- Processed data is reproducible from raw via `scripts/ingest.py`
- All Python scripts use argparse for CLI usage
- Search results return top-k with similarity scores and source attribution

## Experts Tracked
1. **Mitko Vasilev** — Claude Code expert (cataloguing in progress)

## Architecture Overview

### Three-Tier System
1. **Python Layer** — FAISS vector search with sentence-transformers embeddings
2. **Phoenix/Elixir Layer** — Web API + LiveView UI wrapping the Python search
3. **SwiftUI Layer** — Native macOS menubar app calling the Phoenix API

### Data Flow
```
User (menubar search bar)
  → SwiftUI SearchViewModel (debounced 300ms)
    → APIClient GET /api/search?q=...
      → Phoenix SearchController
        → ExpertiseApi.Search (System.cmd python3 search.py --json)
          → FAISS vector index lookup
        ← JSON results
      ← HTTP 200 JSON response
    ← Decoded [SearchResult]
  → SwiftUI ResultCard list
```

### API Contract
- `GET /api/search?q=<query>&top_k=5&min_score=0.2` — Returns search results
- `GET /api/health` — Health check
- `GET /` — Phoenix LiveView web UI

## Usage

### Quick Start (all services)
```bash
./scripts/run.sh
```

### Individual Components
```bash
# Python: Install dependencies
pip install -r requirements.txt

# Python: Ingest, embed, search
python scripts/ingest.py --author mitko-vasilev
python scripts/embed.py
python scripts/search.py "how to use claude code hooks"

# Phoenix: Start API server
cd expertise_api && mix deps.get && mix phx.server

# Swift: Build and run menubar app
cd ExpertiseApp && swift build && .build/debug/ExpertiseApp
```

## Project Management
- **Plane Project**: CEV (Claude Expertise Vault) on plane.lgtm.build
- **Project ID**: 957bc85a-62f4-4f56-90cb-4778a3050d47
