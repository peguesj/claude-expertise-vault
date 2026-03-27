---
source: https://code.claude.com/docs/en/cli-reference
fetched: 2026-03-27
category: claude-code
---

# CLI Reference

> Complete reference for Claude Code command-line interface, including commands and flags.

## CLI Commands

| Command | Description | Example |
|:--------|:------------|:--------|
| `claude` | Start interactive session | `claude` |
| `claude "query"` | Start interactive session with initial prompt | `claude "explain this project"` |
| `claude -p "query"` | Query via SDK, then exit | `claude -p "explain this function"` |
| `cat file \| claude -p "query"` | Process piped content | `cat logs.txt \| claude -p "explain"` |
| `claude -c` | Continue most recent conversation in current directory | `claude -c` |
| `claude -c -p "query"` | Continue via SDK | `claude -c -p "Check for type errors"` |
| `claude -r "<session>" "query"` | Resume session by ID or name | `claude -r "auth-refactor" "Finish this PR"` |
| `claude update` | Update to latest version | `claude update` |
| `claude auth login` | Sign in. Use `--email`, `--sso`, `--console` flags | `claude auth login --console` |
| `claude auth logout` | Log out | `claude auth logout` |
| `claude auth status` | Show authentication status as JSON (`--text` for human-readable) | `claude auth status` |
| `claude agents` | List all configured subagents, grouped by source | `claude agents` |
| `claude auto-mode defaults` | Print auto mode classifier rules as JSON | `claude auto-mode defaults > rules.json` |
| `claude mcp` | Configure MCP servers | See MCP docs |
| `claude plugin` | Manage plugins (alias: `claude plugins`) | `claude plugin install code-review@claude-plugins-official` |
| `claude remote-control` | Start Remote Control server | `claude remote-control --name "My Project"` |

## CLI Flags

| Flag | Description | Example |
|:-----|:------------|:--------|
| `--add-dir` | Add additional working directories | `claude --add-dir ../apps ../lib` |
| `--agent` | Specify an agent for the current session | `claude --agent my-custom-agent` |
| `--agents` | Define custom subagents dynamically via JSON | `claude --agents '{"reviewer":{"description":"Reviews code","prompt":"You are a code reviewer"}}'` |
| `--allow-dangerously-skip-permissions` | Enable permission bypassing as an option | `claude --permission-mode plan --allow-dangerously-skip-permissions` |
| `--allowedTools` | Tools that execute without prompting | `"Bash(git log *)" "Bash(git diff *)" "Read"` |
| `--append-system-prompt` | Append custom text to end of default system prompt | `claude --append-system-prompt "Always use TypeScript"` |
| `--append-system-prompt-file` | Load additional system prompt text from file | `claude --append-system-prompt-file ./extra-rules.txt` |
| `--bare` | Minimal mode: skip auto-discovery of hooks, skills, plugins, MCP, auto memory, CLAUDE.md | `claude --bare -p "query"` |
| `--betas` | Beta headers to include in API requests (API key users only) | `claude --betas interleaved-thinking` |
| `--chrome` | Enable Chrome browser integration | `claude --chrome` |
| `--continue`, `-c` | Load most recent conversation in current directory | `claude --continue` |
| `--dangerously-skip-permissions` | Skip permission prompts | `claude --dangerously-skip-permissions` |
| `--debug` | Enable debug mode with optional category filtering | `claude --debug "api,mcp"` |
| `--disable-slash-commands` | Disable all skills and commands for this session | `claude --disable-slash-commands` |
| `--disallowedTools` | Tools removed from model's context | `"Bash(git log *)" "Edit"` |
| `--effort` | Set effort level: `low`, `medium`, `high`, `max` (Opus 4.6 only) | `claude --effort high` |
| `--fallback-model` | Enable automatic fallback to specified model when overloaded (print mode only) | `claude -p --fallback-model sonnet "query"` |
| `--fork-session` | Create new session ID instead of reusing original (use with `--resume` or `--continue`) | `claude --resume abc123 --fork-session` |
| `--from-pr` | Resume sessions linked to a specific GitHub PR | `claude --from-pr 123` |
| `--ide` | Auto-connect to IDE on startup | `claude --ide` |
| `--init` | Run initialization hooks and start interactive mode | `claude --init` |
| `--init-only` | Run initialization hooks and exit | `claude --init-only` |
| `--include-partial-messages` | Include partial streaming events (requires `--print` and `--output-format=stream-json`) | `claude -p --output-format stream-json --include-partial-messages "query"` |
| `--input-format` | Specify input format for print mode: `text`, `stream-json` | `claude -p --output-format json --input-format stream-json` |
| `--json-schema` | Get validated JSON output matching a JSON Schema (print mode only) | `claude -p --json-schema '{"type":"object",...}' "query"` |
| `--maintenance` | Run maintenance hooks and exit | `claude --maintenance` |
| `--max-budget-usd` | Maximum dollar amount to spend on API calls (print mode only) | `claude -p --max-budget-usd 5.00 "query"` |
| `--max-turns` | Limit number of agentic turns (print mode only) | `claude -p --max-turns 3 "query"` |
| `--mcp-config` | Load MCP servers from JSON files or strings | `claude --mcp-config ./mcp.json` |
| `--model` | Sets the model for the current session | `claude --model claude-sonnet-4-6` |
| `--name`, `-n` | Set display name for the session | `claude -n "my-feature-work"` |
| `--no-chrome` | Disable Chrome browser integration for this session | `claude --no-chrome` |
| `--no-session-persistence` | Disable session persistence (print mode only) | `claude -p --no-session-persistence "query"` |
| `--output-format` | Specify output format for print mode: `text`, `json`, `stream-json` | `claude -p "query" --output-format json` |
| `--enable-auto-mode` | Unlock auto mode in Shift+Tab cycle (requires Team plan) | `claude --enable-auto-mode` |
| `--permission-mode` | Begin in specified permission mode | `claude --permission-mode plan` |
| `--permission-prompt-tool` | Specify MCP tool to handle permission prompts in non-interactive mode | `claude -p --permission-prompt-tool mcp_auth_tool "query"` |
| `--plugin-dir` | Load plugins from a directory for this session only | `claude --plugin-dir ./my-plugins` |
| `--print`, `-p` | Print response without interactive mode | `claude -p "query"` |
| `--remote` | Create new web session on claude.ai with provided task | `claude --remote "Fix the login bug"` |
| `--remote-control`, `--rc` | Start interactive session with Remote Control enabled | `claude --remote-control "My Project"` |
| `--resume`, `-r` | Resume specific session by ID or name | `claude --resume auth-refactor` |
| `--session-id` | Use specific session ID (must be valid UUID) | `claude --session-id "550e8400-..."` |
| `--setting-sources` | Comma-separated list of setting sources to load | `claude --setting-sources user,project` |
| `--settings` | Path to settings JSON file or JSON string | `claude --settings ./settings.json` |
| `--strict-mcp-config` | Only use MCP servers from `--mcp-config` | `claude --strict-mcp-config --mcp-config ./mcp.json` |
| `--system-prompt` | Replace entire system prompt with custom text | `claude --system-prompt "You are a Python expert"` |
| `--system-prompt-file` | Load system prompt from file, replacing default | `claude --system-prompt-file ./custom-prompt.txt` |
| `--teleport` | Resume a web session in your local terminal | `claude --teleport` |
| `--teammate-mode` | Set how agent team teammates display: `auto`, `in-process`, `tmux` | `claude --teammate-mode in-process` |
| `--tools` | Restrict which built-in tools Claude can use | `claude --tools "Bash,Edit,Read"` |
| `--verbose` | Enable verbose logging | `claude --verbose` |
| `--version`, `-v` | Output version number | `claude -v` |
| `--worktree`, `-w` | Start Claude in isolated git worktree | `claude -w feature-auth` |

## System Prompt Flags

| Flag | Behavior |
|:-----|:---------|
| `--system-prompt` | Replaces the entire default prompt |
| `--system-prompt-file` | Replaces with file contents |
| `--append-system-prompt` | Appends to the default prompt |
| `--append-system-prompt-file` | Appends file contents to the default prompt |

`--system-prompt` and `--system-prompt-file` are mutually exclusive. Append flags can combine with either replacement flag.

**Recommendation**: Use append flags unless you need complete control. Appending preserves Claude Code's built-in capabilities while adding your requirements.
