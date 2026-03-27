# Claude Expertise Vault — Phoenix API

Version: see `../VERSION` (current: 1.0.0 / API: 4.1.0)

Phoenix/Elixir backend for the Claude Expertise Vault. Provides the JSON API, LiveView search UI, Python pipeline bridge, AuthoritySyncer GenServer, and analytics.

## Quick Start

```bash
mix deps.get
mix phx.server
# Listening on http://localhost:8645
```

Or with interactive shell:
```bash
iex -S mix phx.server
```

## Key Modules

| Module | Description |
|--------|-------------|
| `ExpertiseApi.Search` | Python bridge → `scripts/search.py` |
| `ExpertiseApi.Ask` | Python bridge → `scripts/ask.py` |
| `ExpertiseApi.Pipeline` | Orchestrates scan/import/embed pipeline |
| `ExpertiseApi.Ingest` | Post ingestion from userscript/extension |
| `ExpertiseApi.Database` | SQLite taxonomy/resource bridge |
| `ExpertiseApi.Analytics` | Search events, preferences, recommendations |
| `ExpertiseApi.Authorities` | Authority CRUD + Python bridge → `scripts/fetch.py` |
| `ExpertiseApi.AuthoritySyncer` | GenServer — checks due authorities every 5 min |
| `ExpertiseApiWeb.SearchLive` | LiveView search UI (liquid glass) |
| `ExpertiseApiWeb.SearchController` | Core search/ask/pipeline endpoints |
| `ExpertiseApiWeb.AnalyticsController` | Analytics endpoints |
| `ExpertiseApiWeb.AuthorityController` | Authority management endpoints |
| `ExpertiseApiWeb.DocsController` | Scalar UI + OpenAPI spec |

## API Reference

Full spec at `GET /api/openapi.yaml` or browse the Scalar UI at `GET /docs`.

### Core
- `GET /api/search?q=<query>&top_k=5&min_score=0.2`
- `GET /api/ask?q=<question>&top_k=8`
- `GET /api/stats`
- `GET /api/health`
- `POST /api/ingest`
- `POST /api/scan`
- `POST /api/import`

### Analytics
- `POST /api/analytics/search`
- `POST /api/analytics/interaction`
- `GET /api/analytics/top-queries`
- `GET /api/analytics/recommendations`
- `GET /api/analytics/preferences`
- `GET /api/analytics/insights-feed`

### Authorities
- `GET /api/authorities`
- `POST /api/authorities`
- `GET /api/authorities/:slug`
- `POST /api/authorities/:slug/sync`
- `GET /api/authorities/syncer/status`

## Development Notes

- Python scripts are called via `System.cmd("python3", [...])` — ensure the virtualenv is active or dependencies installed globally.
- AuthoritySyncer is in the supervision tree (`ExpertiseApi.Application`) and starts automatically.
- CORS is configured via `ExpertiseApiWeb.Plugs.CORS` for `localhost:*` origins (Swift app + browser extensions).
- LiveView uses the liquid glass theme; assets compiled via esbuild + Tailwind CSS v4.
