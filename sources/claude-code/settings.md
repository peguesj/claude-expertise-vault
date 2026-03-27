---
source: https://code.claude.com/docs/en/settings
fetched: 2026-03-27
category: claude-code
---

# Claude Code Settings

> Configure Claude Code with global and project-level settings, and environment variables.

## Configuration Scopes

| Scope | Location | Who it affects | Shared with team? |
|:------|:---------|:---------------|:-----------------|
| **Managed** | Server-managed settings, plist/registry, or system-level `managed-settings.json` | All users on the machine | Yes (deployed by IT) |
| **User** | `~/.claude/` directory | You, across all projects | No |
| **Project** | `.claude/` in repository | All collaborators | Yes (committed to git) |
| **Local** | `.claude/settings.local.json` | You, in this repository only | No (gitignored) |

### When to Use Each Scope

**Managed scope**: Security policies enforced organization-wide.

**User scope**: Personal preferences (editor choice, notification preferences, default model).

**Project scope**: Team settings committed to git (coding standards, allowed/blocked tools).

**Local scope**: Machine-specific overrides for the project that shouldn't be shared.

## Settings Files

| Scope | File |
|-------|------|
| User | `~/.claude/settings.json` |
| Project | `.claude/settings.json` |
| Local | `.claude/settings.local.json` |
| Managed (macOS) | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Managed (Linux/WSL) | `/etc/claude-code/managed-settings.json` |
| Managed (Windows) | `C:\Program Files\ClaudeCode\managed-settings.json` |

## Key Settings Reference

### Permissions

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git *)",
      "Read(~/.ssh/*)",
      "Edit(src/**/*.ts)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Agent(Explore)",
      "Skill(deploy *)"
    ]
  }
}
```

### Permission Rule Syntax

| Pattern | Description |
|---------|-------------|
| `Bash(git *)` | Bash commands matching `git *` |
| `Edit(src/**/*.ts)` | Edit operations on TypeScript files |
| `Agent(Explore)` | Blocking a specific subagent |
| `Skill(deploy *)` | Blocking skills matching `deploy *` |
| `Read` | All Read operations |
| `Bash` | All Bash operations |

### Model Configuration

```json
{
  "model": "claude-sonnet-4-6",
  "smallFastModel": "claude-haiku-4-5",
  "agent": "my-custom-agent"
}
```

### Auto Memory

```json
{
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "~/my-custom-memory-dir"
}
```

### Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/pre-bash-check.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "npm run lint",
            "async": true
          }
        ]
      }
    ]
  }
}
```

### MCP Servers

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed"]
    }
  }
}
```

### CLAUDE.md Exclusions

```json
{
  "claudeMdExcludes": [
    "**/other-team/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

### Environment Variables

```json
{
  "env": {
    "NODE_ENV": "development",
    "CUSTOM_VAR": "value"
  }
}
```

### Disable All Hooks

```json
{
  "disableAllHooks": true
}
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | API key for authentication |
| `ANTHROPIC_MODEL` | Default model to use |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | Set `1` to disable auto memory |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Set `1` to disable background tasks |
| `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | Set `1` to load CLAUDE.md from `--add-dir` directories |
| `CLAUDE_CODE_NEW_INIT` | Set `true` to enable interactive `/init` multi-phase flow |
| `CLAUDE_CODE_SIMPLE` | Set by `--bare` mode |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` | Set `1` to strip credentials from subprocess environments |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Override auto-compaction threshold percentage (default: 95) |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Override model for all subagents |
| `CLAUDE_CODE_MCP_SERVER_NAME` | Current MCP server name (available in MCP helper scripts) |
| `CLAUDE_CODE_MCP_SERVER_URL` | Current MCP server URL (available in MCP helper scripts) |
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` | Override character budget for skill descriptions |
| `OTEL_LOG_TOOL_DETAILS` | Set `1` to include `tool_parameters` in OpenTelemetry events |

## Settings Precedence

Managed policy > Local > Project > User (highest priority wins)

## Opening the Settings UI

Run `/config` in the interactive REPL to open a tabbed Settings interface.
