# Claude Expertise Scraper - Userscript

## Install

1. Install [Tampermonkey](https://www.tampermonkey.net/) (Chrome/Edge/Firefox) or [Greasemonkey](https://www.greasespot.net/) (Firefox).
2. Open Tampermonkey Dashboard > Utilities > Import from file > select `claude-expertise-scraper.user.js`.
   - Or: create a new script in Tampermonkey, paste the full contents of `claude-expertise-scraper.user.js`, and save.
3. The "CE" button appears on every page. Click it or press `Ctrl+Shift+E` to extract content.

## Usage

- **Single post**: Navigate to any page, click "CE" button, review the preview, then "Copy JSONL" or "Send to API".
- **Batch mode**: On feed pages (LinkedIn, X timelines, Reddit), the button shows a badge count. Click "Batch (N)" in the panel header to select and export multiple posts.
- **Settings**: Click the gear/Settings button to configure the API endpoint (default: `http://localhost:8645/api/ingest`).

## Supported Platforms

LinkedIn, X/Twitter, GitHub, YouTube, HackerNews, Reddit, and any blog/article page (readability heuristics).
