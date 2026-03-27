---
source: https://code.claude.com/docs/en/memory
fetched: 2026-03-27
category: claude-code
---

# How Claude Remembers Your Project

> Give Claude persistent instructions with CLAUDE.md files, and let Claude accumulate learnings automatically with auto memory.

Each Claude Code session begins with a fresh context window. Two mechanisms carry knowledge across sessions:

- **CLAUDE.md files**: instructions you write to give Claude persistent context
- **Auto memory**: notes Claude writes itself based on your corrections and preferences

## CLAUDE.md vs Auto Memory

| | CLAUDE.md files | Auto memory |
|:--|:--|:--|
| **Who writes it** | You | Claude |
| **What it contains** | Instructions and rules | Learnings and patterns |
| **Scope** | Project, user, or org | Per working tree |
| **Loaded into** | Every session | Every session (first 200 lines or 25KB) |
| **Use for** | Coding standards, workflows, project architecture | Build commands, debugging insights, preferences Claude discovers |

## CLAUDE.md Files

CLAUDE.md files are markdown files that give Claude persistent instructions. You write these in plain text; Claude reads them at the start of every session.

### Where to Put CLAUDE.md Files

| Scope | Location | Purpose | Shared with |
|-------|----------|---------|-------------|
| **Managed policy** | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md` | Organization-wide, managed by IT/DevOps | All users in org |
| **Project instructions** | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Team-shared instructions | Team via source control |
| **User instructions** | `~/.claude/CLAUDE.md` | Personal preferences for all projects | Just you |

CLAUDE.md files in the directory hierarchy above the working directory are loaded in full at launch. Files in subdirectories load on demand when Claude reads files in those directories.

### Setting Up a Project CLAUDE.md

Run `/init` to generate a starting CLAUDE.md automatically. Claude analyzes your codebase and creates a file with build commands, test instructions, and project conventions.

Set `CLAUDE_CODE_NEW_INIT=true` to enable interactive multi-phase flow: asks which artifacts to set up, explores codebase with subagent, fills in gaps via follow-up, presents reviewable proposal before writing.

### Writing Effective Instructions

- **Size**: target under 200 lines per file. Longer files consume more context and reduce adherence.
- **Structure**: use markdown headers and bullets to group related instructions.
- **Specificity**: write instructions concrete enough to verify:
  - "Use 2-space indentation" instead of "Format code properly"
  - "Run `npm test` before committing" instead of "Test your changes"
  - "API handlers live in `src/api/handlers/`" instead of "Keep files organized"
- **Consistency**: if two rules contradict each other, Claude may pick one arbitrarily.

### Importing Additional Files

Use `@path/to/import` syntax:
```text
See @README for project overview and @package.json for available npm commands.

# Additional Instructions
- git workflow @docs/git-instructions.md
```

For personal preferences not checked in:
```text
# Individual Preferences
- @~/.claude/my-project-instructions.md
```

### AGENTS.md

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repo already uses `AGENTS.md` for other agents:
```markdown
@AGENTS.md

## Claude Code

Use plan mode for changes under `src/billing/`.
```

### How CLAUDE.md Files Load

Claude Code reads CLAUDE.md files by walking up the directory tree from your cwd. Running in `foo/bar/` loads both `foo/bar/CLAUDE.md` and `foo/CLAUDE.md`.

Block-level HTML comments (`<!-- maintainer notes -->`) are stripped before injection into context. Use them for notes that don't spend context tokens.

### Loading from Additional Directories

```bash
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ../shared-config
```

### Organize Rules with `.claude/rules/`

Place markdown files in `.claude/rules/` for larger projects:
```text
your-project/
├── .claude/
│   ├── CLAUDE.md
│   └── rules/
│       ├── code-style.md
│       ├── testing.md
│       └── security.md
```

#### Path-Specific Rules

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Development Rules

- All API endpoints must include input validation
- Use the standard error response format
```

Glob patterns:
| Pattern | Matches |
|---------|---------|
| `**/*.ts` | All TypeScript files in any directory |
| `src/**/*` | All files under `src/` |
| `*.md` | Markdown files in project root |
| `src/components/*.tsx` | React components in specific directory |

#### User-Level Rules

Personal rules in `~/.claude/rules/` apply to every project on your machine.

### Excluding Specific CLAUDE.md Files

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

## Auto Memory

Auto memory lets Claude accumulate knowledge across sessions without you writing anything: build commands, debugging insights, architecture notes, code style preferences, workflow habits.

### Requirements

Auto memory requires Claude Code v2.1.59 or later. Check: `claude --version`.

### Enable or Disable

Auto memory is on by default. Toggle with `/memory` or via settings:
```json
{
  "autoMemoryEnabled": false
}
```

Or via environment: `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.

### Storage Location

Each project: `~/.claude/projects/<project>/memory/`

The `<project>` path is derived from the git repository, so all worktrees and subdirectories share one directory.

```text
~/.claude/projects/<project>/memory/
├── MEMORY.md          # Concise index, loaded into every session
├── debugging.md       # Detailed notes on debugging patterns
├── api-conventions.md # API design decisions
└── ...
```

Custom location:
```json
{
  "autoMemoryDirectory": "~/my-custom-memory-dir"
}
```

### How It Works

- First 200 lines of `MEMORY.md` (or first 25KB, whichever comes first) loaded at start of every conversation
- Content beyond that threshold not loaded at session start
- Topic files (`debugging.md`, `patterns.md`, etc.) read on demand by Claude
- Auto memory is machine-local — not shared across machines or cloud environments

### Audit and Edit

Auto memory files are plain markdown. Run `/memory` to browse and open files from within a session.

When you ask Claude to remember something ("always use pnpm, not npm"), Claude saves it to auto memory. To add to CLAUDE.md instead, ask Claude directly or edit the file yourself via `/memory`.

## View and Edit with `/memory`

The `/memory` command lists all CLAUDE.md and rules files loaded in your current session, lets you toggle auto memory on or off, and provides a link to open the auto memory folder.

## Troubleshoot Memory Issues

### Claude Isn't Following My CLAUDE.md

1. Run `/memory` to verify CLAUDE.md files are being loaded
2. Check that the relevant CLAUDE.md is in a location that gets loaded
3. Make instructions more specific
4. Look for conflicting instructions across CLAUDE.md files

For instructions at system prompt level: use `--append-system-prompt`. (Must be passed every invocation.)

Use `InstructionsLoaded` hook to log exactly which instruction files are loaded, when they load, and why.

### CLAUDE.md Is Too Large

Files over 200 lines: move detailed content to separate files referenced with `@path` imports, or split using `.claude/rules/` files.

### Instructions Lost After `/compact`

CLAUDE.md fully survives compaction. After `/compact`, Claude re-reads from disk and re-injects. If an instruction disappeared, it was only given in conversation, not written to CLAUDE.md.
