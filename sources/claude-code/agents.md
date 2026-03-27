---
source: https://code.claude.com/docs/en/sub-agents
fetched: 2026-03-27
category: claude-code
---

# Create Custom Subagents

> Create and use specialized AI subagents in Claude Code for task-specific workflows and improved context management.

Subagents are specialized AI assistants that handle specific types of tasks. Each runs in its own context window with a custom system prompt, specific tool access, and independent permissions.

**Note**: For multiple agents working in parallel across separate sessions, see agent teams instead. Subagents work within a single session.

## Benefits

- **Preserve context**: keep exploration and implementation out of your main conversation
- **Enforce constraints**: limit which tools a subagent can use
- **Reuse configurations**: user-level subagents available across projects
- **Specialize behavior**: focused system prompts for specific domains
- **Control costs**: route tasks to faster, cheaper models like Haiku

## Built-in Subagents

| Agent | Model | Purpose |
|-------|-------|---------|
| **Explore** | Haiku (fast) | File discovery, code search, codebase exploration. Read-only tools. |
| **Plan** | Inherits | Research for plan mode. Read-only tools. |
| **General-purpose** | Inherits | Complex multi-step tasks requiring exploration and action. All tools. |
| **Bash** | Inherits | Running terminal commands in separate context |
| **statusline-setup** | Sonnet | When you run `/statusline` |
| **Claude Code Guide** | Haiku | When you ask questions about Claude Code features |

## Quickstart: Create Your First Subagent

1. Run `/agents` in Claude Code
2. Select **Create new agent** → choose scope (Personal = `~/.claude/agents/`)
3. Select **Generate with Claude** and describe the subagent
4. Select tools, model, color, memory scope
5. Press `s` or `Enter` to save

Try it:
```text
Use the code-improver agent to suggest improvements in this project
```

## Subagent Scope and Priority

| Location | Scope | Priority |
|----------|-------|---------|
| `--agents` CLI flag | Current session | 1 (highest) |
| `.claude/agents/` | Current project | 2 |
| `~/.claude/agents/` | All your projects | 3 |
| Plugin's `agents/` directory | Where plugin enabled | 4 (lowest) |

## Writing Subagent Files

YAML frontmatter + markdown system prompt:

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

### Supported Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique ID: lowercase letters and hyphens |
| `description` | Yes | When Claude should delegate to this subagent |
| `tools` | No | Tools the subagent can use. Inherits all if omitted |
| `disallowedTools` | No | Tools to deny |
| `model` | No | `sonnet`, `opus`, `haiku`, full model ID, or `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, or `plan` |
| `maxTurns` | No | Max agentic turns before stopping |
| `skills` | No | Skills to load into subagent context at startup |
| `mcpServers` | No | MCP servers available to subagent |
| `hooks` | No | Lifecycle hooks scoped to this subagent |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local` |
| `background` | No | Set `true` to always run as background task |
| `effort` | No | Effort level: `low`, `medium`, `high`, `max` (Opus 4.6 only) |
| `isolation` | No | Set `worktree` to run in temporary git worktree |
| `initialPrompt` | No | Auto-submitted first user turn when agent runs as main session agent |

## CLI-Defined Subagents

Pass JSON via `--agents` for session-only subagents (useful for testing):

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer. Focus on code quality, security, and best practices.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

## Model Selection

1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable (if set)
2. Per-invocation `model` parameter
3. Subagent definition's `model` frontmatter
4. Main conversation's model

## Tool Control

**Allowlist (only these tools)**:
```yaml
tools: Read, Grep, Glob, Bash
```

**Denylist (inherit all except these)**:
```yaml
disallowedTools: Write, Edit
```

**Restrict spawnable subagents**:
```yaml
tools: Agent(worker, researcher), Read, Bash
```

## Scoping MCP Servers to a Subagent

```yaml
---
name: browser-tester
description: Tests features in a real browser using Playwright
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - github  # reference existing configured server
---
```

## Persistent Memory

```yaml
---
name: code-reviewer
description: Reviews code for quality and best practices
memory: user
---
```

| Scope | Location | Use when |
|-------|----------|---------|
| `user` | `~/.claude/agent-memory/<name>/` | learnings across all projects |
| `project` | `.claude/agent-memory/<name>/` | project-specific, shareable |
| `local` | `.claude/agent-memory-local/<name>/` | project-specific, private |

## Permission Modes

| Mode | Behavior |
|------|---------|
| `default` | Standard permission checking with prompts |
| `acceptEdits` | Auto-accept file edits |
| `dontAsk` | Auto-deny permission prompts |
| `bypassPermissions` | Skip permission prompts |
| `plan` | Plan mode (read-only exploration) |

**Warning**: `bypassPermissions` skips prompts. Writes to `.git`, `.claude`, `.vscode`, `.idea` still prompt.

## Hooks in Subagents

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-command.sh $TOOL_INPUT"
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/run-linter.sh"
```

## Working with Subagents

### Automatic Delegation
Claude delegates based on task description matching subagent descriptions. Add "use proactively" to encourage delegation.

### Explicit Invocation
- **Natural language**: "Use the test-runner subagent to fix failing tests"
- **@-mention**: `@"code-reviewer (agent)" look at the auth changes`
- **Session-wide**: `claude --agent code-reviewer`

Or set default in `.claude/settings.json`:
```json
{
  "agent": "code-reviewer"
}
```

### Foreground vs Background
- **Foreground**: blocks main conversation, permission prompts pass through
- **Background**: runs concurrently, press `Ctrl+B` to background a running task

Disable background tasks: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`

### Resume a Subagent
Each invocation creates fresh context. To continue an existing subagent:
```text
Use the code-reviewer subagent to review the authentication module
[Agent completes]
Continue that code review and now analyze the authorization logic
```

Subagent transcripts stored at: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`

## Disable Specific Subagents

```json
{
  "permissions": {
    "deny": ["Agent(Explore)", "Agent(my-custom-agent)"]
  }
}
```

Or via CLI: `claude --disallowedTools "Agent(Explore)"`

## Example: Code Reviewer (Read-Only)

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- No duplicated code
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage
- Performance considerations addressed
```

## Example: Database Query Validator (Hook-Protected)

```markdown
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---

You are a database analyst with read-only access. Execute SELECT queries to answer questions about the data.
```

Validation script:
```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE)\b' > /dev/null; then
  echo "Blocked: Only SELECT queries are allowed" >&2
  exit 2
fi
exit 0
```

## Best Practices

- Design focused subagents: each should excel at one specific task
- Write detailed descriptions: Claude uses description to decide when to delegate
- Limit tool access: grant only necessary permissions
- Check project subagents into version control: share with your team
