# Anthropic Authoritative Sources Index

Generated: 2026-03-27

This index tracks all Anthropic authoritative content fetched for the claude-expertise-vault knowledge base.

**Note**: As of 2026-03-27, Claude Code docs have moved from `docs.anthropic.com/en/docs/claude-code/*` to `code.claude.com/docs/en/*`. The API and models docs have moved to `platform.claude.com/docs/en/*`.

---

## Claude Code

| File | Source | Last Fetched |
|------|--------|-------------|
| `claude-code/overview.md` | https://code.claude.com/docs/en/overview | 2026-03-27 |
| `claude-code/hooks.md` | https://code.claude.com/docs/en/hooks | 2026-03-27 |
| `claude-code/memory.md` | https://code.claude.com/docs/en/memory | 2026-03-27 |
| `claude-code/settings.md` | https://code.claude.com/docs/en/settings | 2026-03-27 |
| `claude-code/mcp.md` | https://code.claude.com/docs/en/mcp | 2026-03-27 |
| `claude-code/cli-reference.md` | https://code.claude.com/docs/en/cli-reference | 2026-03-27 |
| `claude-code/agents.md` | https://code.claude.com/docs/en/sub-agents | 2026-03-27 |
| `claude-code/slash-commands.md` | https://code.claude.com/docs/en/skills | 2026-03-27 |
| `claude-code/CHANGELOG.md` | https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md | 2026-03-27 |

## API Reference

| File | Source | Last Fetched |
|------|--------|-------------|
| `api/models.md` | https://platform.claude.com/docs/en/docs/about-claude/models | 2026-03-27 |
| `api/getting-started.md` | https://platform.claude.com/docs/en/api/getting-started | 2026-03-27 |
| `api/tool-use.md` | https://platform.claude.com/docs/en/docs/build-with-claude/tool-use/overview | 2026-03-27 |

## Model Spec

| File | Source | Last Fetched |
|------|--------|-------------|
| `model-spec/spec.md` | https://www.anthropic.com/news/claude-character + https://www.anthropic.com/transparency | 2026-03-27 |

**Note**: The `anthropics/model-spec` GitHub repository returned 404. Content sourced from anthropic.com published character spec and transparency hub instead.

## Blog / News

| File | Source | Last Fetched |
|------|--------|-------------|
| `blog/recent-announcements.md` | https://www.anthropic.com/news | 2026-03-27 |

## MCP (Model Context Protocol)

| File | Source | Last Fetched |
|------|--------|-------------|
| `mcp/introduction.md` | https://modelcontextprotocol.io/introduction | 2026-03-27 |
| `mcp/specification.md` | https://modelcontextprotocol.io/specification | 2026-03-27 |

---

## Key Findings vs Prior Assumptions

### URL Changes (CRITICAL)
- **Claude Code docs moved**: `docs.anthropic.com/en/docs/claude-code/*` → `code.claude.com/docs/en/*` (301 permanent redirect)
- **API/Platform docs moved**: `docs.anthropic.com/en/api/*` → `platform.claude.com/docs/en/*` (301 permanent redirect)
- **model-spec GitHub repo**: `anthropics/model-spec` main branch returns 404 — repo may have moved or been reorganized

### Model Updates
- **Current latest models**: Claude Opus 4.6, Claude Sonnet 4.6, Claude Haiku 4.5 (not Opus 4, Sonnet 4)
- **Opus 4.6**: 1M token context, 128k max output, $5/$25 per MTok, Training cutoff Jan 2026
- **Sonnet 4.6**: 1M token context, 64k max output, $3/$15 per MTok, Knowledge cutoff Aug 2025
- **Claude Haiku 3 DEPRECATED**: Retires April 19, 2026 — if CCEM uses this, urgent migration needed

### New Claude Code Capabilities (2026)
- **Skills system** replaced/extended slash commands — `.claude/commands/` still works but skills have more features
- **Subagents** with full frontmatter configuration (model, tools, hooks, memory, isolation, effort)
- **Sessions** with resume, fork, teleport capabilities
- **Remote Control**: Control from mobile/web while terminal session runs
- **Channels**: Push events from Telegram, Discord, iMessage into sessions
- **Desktop app**: New standalone app with visual diff review, scheduled tasks
- **`/batch`**: Parallel large-scale codebase changes via worktrees
- **`--bare` mode**: Faster scripted usage skipping hooks/skills/plugins
- **PreToolUse `if` field**: Conditional hook execution using permission rule syntax

### Hooks New Events (2026)
New hook events not in older versions: `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`, `TaskCreated`, `TaskCompleted`, `CwdChanged`, `FileChanged`, `InstructionsLoaded`

### CCEM APM Integration Notes
- CCEM APM's `session_init.sh` `SessionStart` hook now has access to `source` and `model` fields in hook input
- PreToolUse hook input includes `agent_id` and `agent_type` when running inside a subagent
- The `SubagentStart` matcher matches the agent **type name** (e.g., `Explore`, `Plan`, or custom names)

---

## Fetch Status Summary

| Category | Files Fetched | Status |
|----------|---------------|--------|
| Claude Code | 9 | All successful |
| API | 3 | All successful |
| Model Spec | 1 | Partial (GitHub 404, used anthropic.com) |
| Blog/News | 1 | Successful |
| MCP | 2 | All successful |
| **Total** | **16** | **16/16 files created** |
