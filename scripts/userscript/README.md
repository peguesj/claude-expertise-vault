# Claude Expertise Scraper — Userscript

Version: see `../../VERSION` (current: 4.1.0)

Tampermonkey/Greasemonkey userscript for scraping expert content into the Claude Expertise Vault. Works on LinkedIn, X/Twitter, GitHub, YouTube, HackerNews, Reddit, and any blog/article page.

## Install

1. Install [Tampermonkey](https://www.tampermonkey.net/) (Chrome/Edge/Firefox) or [Greasemonkey](https://www.greasespot.net/) (Firefox).
2. Open Tampermonkey Dashboard > Utilities > Import from file > select `claude-expertise-scraper.user.js`.
   - Or: create a new script in Tampermonkey, paste the full contents, and save.
3. The "CE" button appears on every page. Click it or press `Ctrl+Shift+E` to extract content.

## Usage

- **Single post**: Navigate to any page, click "CE", review the preview, then "Copy JSONL" or "Send to API".
- **Batch mode**: On feed pages (LinkedIn, X timelines, Reddit), the button shows a badge count. Click "Batch (N)" to select and export multiple posts.
- **Settings**: Click the gear icon to configure the API endpoint (default: `http://localhost:8645/api/ingest`) and Anthropic API key for AI refinement.

## Authority Auto-Detect (v4.1.0)

When you navigate to a registered authority's profile page (LinkedIn, GitHub, etc.), the userscript automatically:
1. Detects the authority from the URL
2. Scrapes visible posts
3. POSTs to `/api/ingest` with authority metadata
4. Shows a toast notification confirming the sync

A 30-minute cooldown per authority prevents duplicate scrapes within a session.

## Supported Platforms

LinkedIn, X/Twitter, GitHub, YouTube, HackerNews, Reddit, and any blog/article page (readability heuristics).

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| API Endpoint | `http://localhost:8645/api/ingest` | POST target for ingested data |
| Anthropic API Key | (blank) | For AI refinement via claude-haiku (~$0.001/post). Leave blank to disable. |
| Default Author Override | (blank) | Overrides extracted author on every export |
| Extra Tags | (blank) | Comma-separated tags appended to every export |
