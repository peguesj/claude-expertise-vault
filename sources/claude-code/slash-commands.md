---
source: https://code.claude.com/docs/en/skills
fetched: 2026-03-27
category: claude-code
---

# Skills and Slash Commands

> Create, manage, and share skills to extend Claude's capabilities in Claude Code.

Skills extend what Claude can do. Create a `SKILL.md` file with instructions, and Claude adds it to its toolkit.

**Key note**: Custom commands have been merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way. Existing `.claude/commands/` files keep working.

Claude Code skills follow the [Agent Skills](https://agentskills.io) open standard.

## Bundled Skills

These ship with Claude Code, available in every session:

| Skill | Purpose |
|:------|:--------|
| `/batch <instruction>` | Orchestrate large-scale changes across codebase in parallel. Spawns one background agent per unit in isolated git worktrees. Requires git repository. |
| `/claude-api` | Load Claude API reference material for your project's language. Also activates automatically when your code imports `anthropic`, `@anthropic-ai/sdk`, etc. |
| `/debug [description]` | Enable debug logging for current session and troubleshoot by reading session debug log. |
| `/loop [interval] <prompt>` | Run a prompt repeatedly on an interval. Example: `/loop 5m check if the deploy finished` |
| `/simplify [focus]` | Review recently changed files for code reuse, quality, efficiency. Spawns three review agents in parallel. |

## Where Skills Live

| Location | Path | Applies to |
|:---------|:-----|:-----------|
| Enterprise | Managed settings | All users in org |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin enabled |

Priority: enterprise > personal > project. Plugin skills use `plugin-name:skill-name` namespace.

## Creating Your First Skill

```bash
mkdir -p ~/.claude/skills/explain-code
```

Create `~/.claude/skills/explain-code/SKILL.md`:
```yaml
---
name: explain-code
description: Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work?"
---

When explaining code, always include:

1. **Start with an analogy**: Compare the code to something from everyday life
2. **Draw a diagram**: Use ASCII art to show flow, structure, or relationships
3. **Walk through the code**: Explain step-by-step what happens
4. **Highlight a gotcha**: What's a common mistake or misconception?
```

Invoke directly:
```text
/explain-code src/auth/login.ts
```

Or let Claude invoke automatically when you ask "How does this code work?"

## Frontmatter Reference

```yaml
---
name: my-skill
description: What this skill does
disable-model-invocation: true
allowed-tools: Read, Grep
---
```

| Field | Required | Description |
|:------|:---------|:------------|
| `name` | No | Display name. If omitted, uses directory name. Max 64 chars, lowercase, hyphens only. |
| `description` | Recommended | What the skill does. Claude uses this to decide when to apply. |
| `argument-hint` | No | Hint shown during autocomplete. Example: `[issue-number]` |
| `disable-model-invocation` | No | Set `true` to prevent Claude from auto-loading. Use for side-effect workflows. |
| `user-invocable` | No | Set `false` to hide from `/` menu. Use for background knowledge. |
| `allowed-tools` | No | Tools Claude can use without asking when skill is active. |
| `model` | No | Model to use when skill is active. |
| `effort` | No | Effort level: `low`, `medium`, `high`, `max` (Opus 4.6 only). |
| `context` | No | Set `fork` to run in forked subagent context. |
| `agent` | No | Which subagent type to use when `context: fork` is set. |
| `hooks` | No | Hooks scoped to this skill's lifecycle. |
| `paths` | No | Glob patterns limiting when skill is activated. |
| `shell` | No | Shell for inline commands: `bash` (default) or `powershell`. |

## String Substitutions

| Variable | Description |
|:---------|:------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill |
| `$ARGUMENTS[N]` | Specific argument by 0-based index |
| `$N` | Shorthand for `$ARGUMENTS[N]` |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_SKILL_DIR}` | Directory containing the skill's `SKILL.md` file |

Example:
```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---

Fix GitHub issue $ARGUMENTS following our coding standards.

1. Read the issue description
2. Understand the requirements
3. Implement the fix
4. Write tests
5. Create a commit
```

Usage: `/fix-issue 123` → Claude receives "Fix GitHub issue 123 following our coding standards..."

Multi-argument:
```yaml
---
name: migrate-component
---
Migrate the $0 component from $1 to $2.
```
Usage: `/migrate-component SearchBar React Vue`

## Who Invokes a Skill

| Frontmatter | You can invoke | Claude can invoke |
|:------------|:--------------|:-----------------|
| (default) | Yes | Yes |
| `disable-model-invocation: true` | Yes | No |
| `user-invocable: false` | No | Yes |

## Running Skills in a Subagent

Add `context: fork` to run in isolation:
```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:

1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

The `agent` field specifies which subagent: built-in (`Explore`, `Plan`, `general-purpose`) or any custom subagent.

## Dynamic Context Injection

The `` !`<command>` `` syntax runs shell commands before skill content is sent to Claude:

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

This is preprocessing — Claude only sees the final rendered result.

## Controlling Skill Access

Deny all skills:
```text
# In permissions deny list:
Skill
```

Allow/deny specific skills:
```text
# Allow only specific skills
Skill(commit)
Skill(review-pr *)

# Deny specific skills
Skill(deploy *)
```

## Adding Supporting Files

```text
my-skill/
├── SKILL.md           # Main instructions (required)
├── reference.md       # Detailed API docs - loaded when needed
├── examples.md        # Usage examples
└── scripts/
    └── helper.py      # Script Claude can execute
```

Reference supporting files from `SKILL.md` so Claude knows what they contain.

**Tip**: Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

## Sharing Skills

- **Project skills**: commit `.claude/skills/` to version control
- **Plugins**: create `skills/` directory in your plugin
- **Managed**: deploy via managed settings for organization-wide distribution

## Extended Thinking in Skills

Include "ultrathink" anywhere in skill content to enable extended thinking.
