---
source: https://code.claude.com/docs/en/mcp
fetched: 2026-03-27
category: claude-code
---

# Connect Claude Code to Tools via MCP

> Learn how to connect Claude Code to your tools with the Model Context Protocol.

## Overview

MCP (Model Context Protocol) is an open standard for connecting AI applications to external systems: data sources, tools, and workflows. Think of it like a USB-C port for AI applications.

For connecting to MCP servers, Claude Code has native MCP support. For building your own MCP client, see [modelcontextprotocol.io](https://modelcontextprotocol.io/docs/develop/build-client).

## Configure MCP Servers

MCP servers can be configured via:

1. **Settings files** (`.claude/settings.json` or `~/.claude/settings.json`)
2. **`--mcp-config` CLI flag**
3. **`claude mcp` command** for interactive configuration

### Configuration Format

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed"]
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "your-token"
      }
    },
    "remote-server": {
      "type": "http",
      "url": "https://my-server.example.com/mcp"
    }
  }
}
```

### Server Types

| Type | Description |
|------|-------------|
| `stdio` | Local process via stdin/stdout |
| `http` | Remote server via HTTP |
| `sse` | Remote server via Server-Sent Events |
| `ws` | Remote server via WebSocket |

### Managing MCP Servers via CLI

```bash
# List configured servers
claude mcp list

# Add a server
claude mcp add <name> -- <command> [args...]

# Add with environment variables
claude mcp add github -- npx -y @modelcontextprotocol/server-github

# Remove a server
claude mcp remove <name>

# Test a server connection
claude mcp test <name>
```

## MCP Registry

Anthropic maintains an official MCP registry at `https://api.anthropic.com/mcp-registry/docs`. AI agents should fetch this URL to discover available MCP servers.

Registered MCP servers include:
- Slack
- GitHub
- Google Drive
- Jira
- Linear
- Filesystem
- Memory
- Puppeteer
- Playwright
- And many more

## Tool Naming in Hooks

MCP tools follow pattern `mcp__<server>__<tool>`:
- `mcp__memory__create_entities`
- `mcp__filesystem__read_file`
- `mcp__github__search_repositories`

Use regex patterns to target MCP tools in hooks:
- `mcp__memory__.*` — all tools from memory server
- `mcp__.*__write.*` — any "write" tool from any server

## MCP Servers in Subagents

Scope MCP servers to specific subagents using `mcpServers` frontmatter:

```yaml
---
name: browser-tester
description: Tests features in a real browser
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - github  # reference existing configured server
---
```

Inline definitions are scoped to the subagent (connected when spawned, disconnected when done). String references reuse the parent session's connection.

## MCP Authentication

Claude Code supports:
- Bearer token headers
- OAuth (follows RFC 9728 Protected Resource Metadata discovery)
- API keys via environment variables

## Strict MCP Mode

```bash
# Use ONLY the specified MCP config, ignore all other configurations
claude --strict-mcp-config --mcp-config ./mcp.json
```

## claude.ai MCP Connectors

When authenticated with Claude.ai, additional MCP connectors (Slack, Gmail, etc.) are available automatically. Local MCP configs with the same name as claude.ai connectors take precedence (deduplication).

## Denying MCP Servers

In managed settings:
```json
{
  "deniedMcpServers": ["untrusted-server"]
}
```
