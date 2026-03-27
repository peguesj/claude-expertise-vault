---
source: https://modelcontextprotocol.io/introduction
fetched: 2026-03-27
category: mcp
---

# What is the Model Context Protocol (MCP)?

MCP (Model Context Protocol) is an open-source standard for connecting AI applications to external systems.

Using MCP, AI applications like Claude or ChatGPT can connect to:
- **Data sources**: local files, databases
- **Tools**: search engines, calculators
- **Workflows**: specialized prompts

Think of MCP like a **USB-C port for AI applications** — just as USB-C provides a standardized way to connect electronic devices, MCP provides a standardized way to connect AI applications to external systems.

## What MCP Enables

- Agents can access your Google Calendar and Notion, acting as a more personalized AI assistant
- Claude Code can generate an entire web app using a Figma design
- Enterprise chatbots can connect to multiple databases across an organization
- AI models can create 3D designs on Blender and print them out using a 3D printer

## Why MCP Matters

**For Developers**: MCP reduces development time and complexity when building or integrating with AI applications.

**For AI Applications/Agents**: MCP provides access to an ecosystem of data sources, tools, and apps which enhances capabilities and improves end-user experience.

**For End-Users**: MCP results in more capable AI applications that can access your data and take actions on your behalf.

## Broad Ecosystem Support

MCP is an open protocol supported across:
- Claude (Anthropic)
- ChatGPT (OpenAI)
- Visual Studio Code (GitHub Copilot)
- Cursor
- MCPJam
- Many others

Build once, integrate everywhere.

## Core Architecture

### Components

1. **MCP Hosts**: Programs like Claude Desktop or VS Code that connect to MCP servers
2. **MCP Clients**: Protocol clients maintained by the host application that connect to servers
3. **MCP Servers**: Services that expose capabilities (data, tools, prompts) through the protocol
4. **Local Data Sources**: Files, databases, services that MCP servers can access
5. **Remote Services**: External APIs that MCP servers can interact with

### Server Capabilities

MCP servers can expose:
- **Resources**: Files, data, content that can be read by clients
- **Tools**: Functions the AI can call to take actions
- **Prompts**: Pre-built prompt templates for common tasks

## Getting Started

### Build Servers
Create MCP servers to expose your data and tools to AI applications.

### Build Clients
Develop applications that connect to MCP servers.

### Build MCP Apps
Build interactive apps that run inside AI clients.

## Protocol Details

- **Open source**: [github.com/modelcontextprotocol](https://github.com/modelcontextprotocol)
- **Language-agnostic**: Supports any programming language
- **Transport options**: stdio (local), HTTP, SSE, WebSocket (remote)
- **Security**: Built-in authentication support
