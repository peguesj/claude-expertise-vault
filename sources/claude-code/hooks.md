---
source: https://code.claude.com/docs/en/hooks
fetched: 2026-03-27
category: claude-code
---

# Hooks Reference

> Hooks are user-defined shell commands, HTTP endpoints, or LLM prompts that execute automatically at specific points in Claude Code's lifecycle.

## Hook Events Timeline

| Event | When it fires |
|:---|:---|
| `SessionStart` | When a session begins or resumes |
| `UserPromptSubmit` | When you submit a prompt, before Claude processes it |
| `PreToolUse` | Before a tool call executes. Can block it |
| `PermissionRequest` | When a permission dialog appears |
| `PostToolUse` | After a tool call succeeds |
| `PostToolUseFailure` | After a tool call fails |
| `Notification` | When Claude Code sends a notification |
| `SubagentStart` | When a subagent is spawned |
| `SubagentStop` | When a subagent finishes |
| `TaskCreated` | When a task is being created via `TaskCreate` |
| `TaskCompleted` | When a task is being marked as completed |
| `Stop` | When Claude finishes responding |
| `StopFailure` | When the turn ends due to an API error |
| `TeammateIdle` | When an agent team teammate is about to go idle |
| `InstructionsLoaded` | When a CLAUDE.md or `.claude/rules/*.md` file is loaded into context |
| `ConfigChange` | When a configuration file changes during a session |
| `CwdChanged` | When the working directory changes |
| `FileChanged` | When a watched file changes on disk |
| `WorktreeCreate` | When a worktree is being created |
| `WorktreeRemove` | When a worktree is being removed |
| `PreCompact` | Before context compaction |
| `PostCompact` | After context compaction completes |
| `Elicitation` | When an MCP server requests user input during a tool call |
| `ElicitationResult` | After a user responds to an MCP elicitation |
| `SessionEnd` | When a session terminates |

## How a Hook Resolves

Example `PreToolUse` hook blocking destructive shell commands:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-rm.sh"
          }
        ]
      }
    ]
  }
}
```

Resolution steps:
1. Event fires with tool input as JSON on stdin
2. Matcher `"Bash"` matches the tool name
3. `if` condition `"Bash(rm *)"` checks command
4. Hook handler runs, inspects command, prints decision to stdout
5. Claude Code reads JSON decision and blocks tool call

## Configuration

### Hook Locations

| Location | Scope | Shareable |
|:---|:---|:---|
| `~/.claude/settings.json` | All your projects | No |
| `.claude/settings.json` | Single project | Yes (committable) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy settings | Organization-wide | Yes (admin-controlled) |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes |
| Skill or agent frontmatter | While component active | Yes |

### Matcher Patterns

The `matcher` field is a regex string. Use `"*"`, `""`, or omit entirely to match all.

| Event | Matches | Example values |
|:---|:---|:---|
| `PreToolUse`, `PostToolUse`, `PermissionRequest` | tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart` | how session started | `startup`, `resume`, `clear`, `compact` |
| `SessionEnd` | why session ended | `clear`, `resume`, `logout`, `prompt_input_exit` |
| `Notification` | notification type | `permission_prompt`, `idle_prompt`, `auth_success` |
| `SubagentStart`, `SubagentStop` | agent type | `Bash`, `Explore`, `Plan`, or custom names |
| `PreCompact`, `PostCompact` | what triggered | `manual`, `auto` |
| `StopFailure` | error type | `rate_limit`, `authentication_failed`, `billing_error`, `invalid_request`, `server_error` |

#### Match MCP Tools

MCP tools follow pattern `mcp__<server>__<tool>`:
- `mcp__memory__.*` — all tools from memory server
- `mcp__.*__write.*` — any "write" tool from any server

### Hook Handler Fields

Four types:
- **Command hooks** (`type: "command"`): run a shell command
- **HTTP hooks** (`type: "http"`): send JSON to HTTP POST endpoint
- **Prompt hooks** (`type: "prompt"`): send prompt to Claude for evaluation
- **Agent hooks** (`type: "agent"`): spawn subagent for verification

#### Common Fields

| Field | Required | Description |
|:---|:---|:---|
| `type` | yes | `"command"`, `"http"`, `"prompt"`, or `"agent"` |
| `if` | no | Permission rule syntax like `"Bash(git *)"` or `"Edit(*.ts)"` |
| `timeout` | no | Seconds before canceling (defaults: 600 command, 30 prompt, 60 agent) |
| `statusMessage` | no | Custom spinner message while hook runs |
| `once` | no | If `true`, runs only once per session (skills only) |

#### Command Hook Fields

| Field | Required | Description |
|:---|:---|:---|
| `command` | yes | Shell command to execute |
| `async` | no | If `true`, runs in background without blocking |
| `shell` | no | `"bash"` (default) or `"powershell"` |

#### HTTP Hook Fields

| Field | Required | Description |
|:---|:---|:---|
| `url` | yes | URL to POST to |
| `headers` | no | Additional HTTP headers |
| `allowedEnvVars` | no | List of env vars for interpolation |

Example:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:8080/hooks/pre-tool-use",
            "timeout": 30,
            "headers": { "Authorization": "Bearer $MY_TOKEN" },
            "allowedEnvVars": ["MY_TOKEN"]
          }
        ]
      }
    ]
  }
}
```

### Reference Scripts by Path

Environment variables for hook scripts:
- `$CLAUDE_PROJECT_DIR`: project root
- `${CLAUDE_PLUGIN_ROOT}`: plugin installation directory
- `${CLAUDE_PLUGIN_DATA}`: plugin persistent data directory

### The `/hooks` Menu

Type `/hooks` in Claude Code to browse configured hooks (read-only view).

### Disable or Remove Hooks

Set `"disableAllHooks": true` in settings to temporarily disable all non-managed hooks.

## Hook Input and Output

### Common Input Fields

| Field | Description |
|:---|:---|
| `session_id` | Current session identifier |
| `transcript_path` | Path to conversation JSON |
| `cwd` | Current working directory |
| `permission_mode` | Current permission mode |
| `hook_event_name` | Name of the event that fired |

When running inside a subagent:
| Field | Description |
|:---|:---|
| `agent_id` | Unique identifier for the subagent |
| `agent_type` | Agent name (e.g., `"Explore"`) |

### PreToolUse Input

```json
{
  "session_id": "abc123",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "cwd": "/home/user/my-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test"
  }
}
```

### Exit Code Output

- **Exit 0**: Success. Claude Code parses stdout for JSON output fields.
- **Exit 2**: Blocking error. stderr text fed back as error message. Effect depends on event.
- **Any other exit code**: Non-blocking error. stderr shown in verbose mode, execution continues.

#### Exit Code 2 Behavior Per Event

| Hook event | Can block? | What happens on exit 2 |
|:---|:---|:---|
| `PreToolUse` | Yes | Blocks the tool call |
| `PermissionRequest` | Yes | Denies the permission |
| `UserPromptSubmit` | Yes | Blocks prompt processing |
| `Stop` | Yes | Prevents Claude from stopping |
| `SubagentStop` | Yes | Prevents subagent from stopping |
| `TaskCreated` | Yes | Prevents task creation |
| `TaskCompleted` | Yes | Prevents task completion |
| `ConfigChange` | Yes | Blocks configuration change |
| `Elicitation` | Yes | Denies the elicitation |
| `WorktreeCreate` | Yes | Causes worktree creation to fail |
| `PostToolUse` | No | Shows stderr to Claude |
| `Notification` | No | Shows stderr to user only |
| `SubagentStart` | No | Shows stderr to user only |
| `SessionStart` | No | Shows stderr to user only |
| `SessionEnd` | No | Shows stderr to user only |
| `PreCompact`, `PostCompact` | No | Shows stderr to user only |

### JSON Output Fields

| Field | Default | Description |
|:---|:---|:---|
| `continue` | `true` | If `false`, Claude stops after hook runs |
| `stopReason` | none | Message shown when `continue` is `false` |
| `suppressOutput` | `false` | If `true`, hides stdout from verbose mode |
| `systemMessage` | none | Warning message shown to user |

Example to stop Claude:
```json
{ "continue": false, "stopReason": "Build failed, fix errors before continuing" }
```

### Decision Control

**Top-level decision** (UserPromptSubmit, PostToolUse, etc.):
```json
{
  "decision": "block",
  "reason": "Test suite must pass before proceeding"
}
```

**PreToolUse**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Database writes are not allowed"
  }
}
```

**PermissionRequest**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": { "command": "npm run lint" }
    }
  }
}
```

## SessionStart Hooks

Useful for loading development context or setting environment variables.

### Persist Environment Variables

Write `export` statements to `CLAUDE_ENV_FILE`:
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
  echo 'export DEBUG_LOG=true' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

`CLAUDE_ENV_FILE` is available for SessionStart, CwdChanged, and FileChanged hooks only.

### SessionStart Input

```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../00893aaf.jsonl",
  "cwd": "/Users/...",
  "hook_event_name": "SessionStart",
  "source": "startup",
  "model": "claude-sonnet-4-6"
}
```

## Async Hooks

Use `"async": true` for fire-and-forget hooks that don't block Claude:
```json
{
  "type": "command",
  "command": "./scripts/log-activity.sh",
  "async": true
}
```

## Practical Examples

### Auto-format after file edits
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"$CLAUDE_PROJECT_DIR\" && npm run format -- $(jq -r '.tool_input.path' < /dev/stdin)"
          }
        ]
      }
    ]
  }
}
```

### Block force pushes to main
```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if echo "$COMMAND" | grep -qE 'git push.*--force.*main|git push.*main.*--force'; then
  echo "Force push to main is not allowed" >&2
  exit 2
fi
exit 0
```

### Log all tool calls
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "echo $(date) tool=$(jq -r '.tool_name') >> ~/claude-tool-log.txt",
            "async": true
          }
        ]
      }
    ]
  }
}
```
