---
source: https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
fetched: 2026-03-27
category: claude-code
---

# Claude Code CHANGELOG

## 2.1.85

- Added `CLAUDE_CODE_MCP_SERVER_NAME` and `CLAUDE_CODE_MCP_SERVER_URL` environment variables to MCP `headersHelper` scripts, allowing one helper to serve multiple servers
- Added conditional `if` field for hooks using permission rule syntax (e.g., `Bash(git *)`) to filter when they run, reducing process spawning overhead
- Added timestamp markers in transcripts when scheduled tasks (`/loop`, `CronCreate`) fire
- Added trailing space after `[Image #N]` placeholder when pasting images
- Deep link queries support up to 5,000 characters
- MCP OAuth now follows RFC 9728 Protected Resource Metadata discovery
- Plugins blocked by organization policy can no longer be installed or enabled
- PreToolUse hooks can now satisfy `AskUserQuestion` by returning `updatedInput` alongside `permissionDecision: "allow"`, enabling headless integrations
- Fixed `/compact` failing with "context exceeded" when conversation too large
- Fixed diff syntax highlighting not working in non-native builds
- Fixed MCP step-up authorization failing when refresh token exists
- Fixed memory leak in remote sessions when streaming response interrupted
- Fixed persistent ECONNRESET errors during edge connection churn
- Fixed prompts getting stuck in queue after running certain slash commands
- Fixed Python Agent SDK: `type:'sdk'` MCP servers passed via `--mcp-config` no longer dropped
- Fixed raw key sequences appearing in prompt when running over SSH

## 2.1.84

- Added PowerShell tool for Windows as opt-in preview
- Added `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL_SUPPORTS` env vars to override capability detection for pinned default models
- Added `CLAUDE_STREAM_IDLE_TIMEOUT_MS` env var to configure streaming idle watchdog threshold (default 90s)
- Added `TaskCreated` hook that fires when a task is created via `TaskCreate`
- Added `WorktreeCreate` hook support for `type: "http"`
- Added `allowedChannelPlugins` managed setting for team/enterprise admins
- Added `x-client-request-id` header to API requests for debugging timeouts
- Added idle-return prompt after 75+ minutes to nudge `/clear`
- Rules and skills `paths:` frontmatter now accepts a YAML list of globs
- MCP tool descriptions capped at 2KB to prevent context bloat
- MCP servers configured locally and via claude.ai connectors deduplicated (local wins)
- Background bash tasks stuck on interactive prompt surface notification after ~45 seconds
- Token counts ≥1M now display as "1.5m" instead of "1512.6k"
- Fixed voice push-to-talk leaking characters into text input
- Fixed `Ctrl+U` being no-op at line boundaries
- Fixed workflow subagents failing with API 400 when outer session uses `--json-schema`

## 2.1.83

- Added `managed-settings.d/` drop-in directory — separate teams can deploy independent policy fragments
- Added `CwdChanged` and `FileChanged` hook events for reactive environment management
- Added `sandbox.failIfUnavailable` setting
- Added `disableDeepLinkRegistration` setting
- Added `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` to strip credentials from subprocess environments
- Added transcript search — press `/` in transcript mode (`Ctrl+O`) to search
- Added `Ctrl+X Ctrl+E` as alias for opening external editor
- Pasted images insert `[Image #N]` chip at cursor
- Agents can now declare `initialPrompt` in frontmatter to auto-submit first turn
- Fixed Claude Code hanging on exit on macOS
- Fixed background subagents becoming invisible after context compaction
- Improved Remote Control session titles
- Changed "stop all background agents" from `Ctrl+F` to `Ctrl+X Ctrl+K`
- Deprecated `TaskOutput` tool in favor of `Read` on background task's output file path
- Plugin options now available externally — plugins can prompt for configuration at enable time
- `Ctrl+L` now clears screen and forces full redraw
- Memory: `MEMORY.md` index now truncates at 25KB as well as 200 lines

## 2.1.81

- Added `--bare` flag for scripted `-p` calls — skips hooks, LSP, plugin sync, skill walks; requires `ANTHROPIC_API_KEY`
- Added `--channels` permission relay
- Fixed multiple concurrent sessions requiring repeated re-authentication

## 2.1.80

- Added `rate_limits` field to statusline scripts for Claude.ai rate limit display
- Added `source: 'settings'` plugin marketplace source
- Added `effort` frontmatter support for skills and slash commands
- Added `--channels` (research preview)
- Fixed `--resume` dropping parallel tool results
- Fixed voice mode WebSocket failures caused by Cloudflare bot detection
