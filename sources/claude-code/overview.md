---
source: https://code.claude.com/docs/en/overview
fetched: 2026-03-27
category: claude-code
---

# Claude Code Overview

> Claude Code is an agentic coding tool that reads your codebase, edits files, runs commands, and integrates with your development tools. Available in your terminal, IDE, desktop app, and browser.

Claude Code is an AI-powered coding assistant that helps you build features, fix bugs, and automate development tasks. It understands your entire codebase and can work across multiple files and tools to get things done.

## Installation

### Native Install (Recommended)

**macOS, Linux, WSL:**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows PowerShell:**
```powershell
irm https://claude.ai/install.ps1 | iex
```

**Windows CMD:**
```batch
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

### Homebrew
```bash
brew install --cask claude-code
```
Note: Homebrew does not auto-update. Run `brew upgrade claude-code` periodically.

### WinGet
```powershell
winget install Anthropic.ClaudeCode
```

### Start Claude Code
```bash
cd your-project
claude
```

## Available Surfaces

- **Terminal**: Full-featured CLI. Edit files, run commands, manage entire project from command line.
- **VS Code**: Inline diffs, @-mentions, plan review, conversation history. Install: search "Claude Code" in Extensions (`Cmd+Shift+X`).
- **Cursor**: Same VS Code extension works in Cursor.
- **JetBrains**: Plugin for IntelliJ IDEA, PyCharm, WebStorm. Install from JetBrains Marketplace.
- **Desktop App**: Standalone app for visual diff review, multiple sessions, scheduled tasks, cloud sessions. Available for macOS and Windows.
- **Web**: Run at claude.ai/code in browser, no local setup needed.

## What You Can Do

### Automate Tedious Tasks
```bash
claude "write tests for the auth module, run them, and fix any failures"
```

### Build Features and Fix Bugs
Describe in plain language. Claude plans, writes code across multiple files, verifies it works.

### Create Commits and Pull Requests
```bash
claude "commit my changes with a descriptive message"
```
Works directly with git: stages changes, writes commit messages, creates branches, opens PRs.

### Connect Tools with MCP
Model Context Protocol (MCP) connects Claude Code to Google Drive, Jira, Slack, custom tooling.

### Customize with CLAUDE.md, Skills, and Hooks
- `CLAUDE.md`: markdown file Claude reads at every session start — set coding standards, architecture decisions, preferred libraries
- Auto memory: Claude builds memories automatically as it works
- Skills (custom commands): Package repeatable workflows your team shares
- Hooks: Run shell commands before/after Claude Code actions

### Run Agent Teams
Spawn multiple Claude Code agents working on different parts simultaneously. A lead agent coordinates.

### Agent SDK
Build custom agents powered by Claude Code's tools with full control over orchestration, tool access, and permissions.

### Pipe, Script, and Automate
```bash
# Analyze recent log output
tail -200 app.log | claude -p "Slack me if you see any anomalies"

# Automate translations in CI
claude -p "translate new strings into French and raise a PR for review"

# Bulk operations across files
git diff main --name-only | claude -p "review these changed files for security issues"
```

### Schedule Recurring Tasks
- Cloud scheduled tasks: run on Anthropic-managed infrastructure (survive computer off)
- Desktop scheduled tasks: run on your machine with local file access
- `/loop`: repeats a prompt within a CLI session

### Work From Anywhere
- **Remote Control**: Continue sessions from phone or any browser
- **Dispatch**: Message Claude a task from phone, open Desktop session it creates
- **Teleport**: Kick off task on web/iOS, pull into terminal with `/teleport`
- **Slack integration**: Mention `@Claude` in Slack, get a pull request back

## Surface Integration Table

| Goal | Best Option |
|------|-------------|
| Continue local session from phone/another device | Remote Control |
| Push events from Telegram, Discord, iMessage, webhooks | Channels |
| Start locally, continue on mobile | Web or Claude iOS app |
| Run Claude on recurring schedule | Cloud or Desktop scheduled tasks |
| Automate PR reviews and issue triage | GitHub Actions or GitLab CI/CD |
| Get automatic code review on every PR | GitHub Code Review |
| Route bug reports from Slack to PRs | Slack integration |
| Debug live web applications | Chrome integration |
| Build custom agents | Agent SDK |

## Next Steps

- Quickstart: first real task, exploring codebase to committing a fix
- Memory: CLAUDE.md files and auto memory
- Common workflows and best practices
- Settings: customize Claude Code
- Troubleshooting: solutions for common issues
