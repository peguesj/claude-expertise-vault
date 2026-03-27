---
source: https://modelcontextprotocol.io/specification
fetched: 2026-03-27
category: mcp
---

# MCP Specification

## Versioning

The Model Context Protocol uses string-based version identifiers following the format `YYYY-MM-DD`, indicating the last date backwards-incompatible changes were made.

The protocol version will **not** be incremented when updated with backwards-compatible changes. This allows incremental improvements while preserving interoperability.

### Revision Status

- **Draft**: In-progress specifications, not yet ready for consumption.
- **Current**: The current protocol version, ready for use, may continue to receive backwards-compatible changes.
- **Final**: Past, complete specifications that will not be changed.

**Current protocol version**: `2025-11-25`

## Version Negotiation

Version negotiation happens during initialization. Clients and servers:
- **MAY** support multiple protocol versions simultaneously
- **MUST** agree on a single version to use for the session
- Handle errors gracefully if version negotiation fails

## Core Protocol Features

### Initialization

The lifecycle begins with an initialization handshake:
1. Client sends `initialize` request with supported versions and capabilities
2. Server responds with chosen version and its capabilities
3. Client sends `initialized` notification to confirm

### Transport Layer

MCP supports multiple transport mechanisms:

| Transport | Use Case |
|-----------|---------|
| `stdio` | Local processes via stdin/stdout |
| `http` | Remote servers via HTTP/HTTPS |
| `sse` | Remote servers via Server-Sent Events |
| `ws` | Remote servers via WebSocket |

### Message Types

- **Requests**: Expect a response, identified by a unique ID
- **Responses**: Reply to requests with success result or error
- **Notifications**: One-way messages, no response expected

### Capabilities

Servers declare their capabilities during initialization:
- `resources`: Exposes data for reading
- `tools`: Exposes functions for calling
- `prompts`: Exposes prompt templates
- `logging`: Supports log message emission
- `experimental`: Unstable features with protocol extension

Clients declare their capabilities:
- `roots`: Supports root list notifications
- `sampling`: Supports LLM sampling requests
- `experimental`: Unstable features

## Resources

Resources let servers expose content that can be read:
- Files (text, binary)
- Database records
- API responses
- Live system data

Resource URIs follow standard formats. Resources can be static or dynamic.

## Tools

Tools let servers expose functions for AI to invoke:

```json
{
  "name": "read_file",
  "description": "Read the contents of a file",
  "inputSchema": {
    "type": "object",
    "properties": {
      "path": {
        "type": "string",
        "description": "Path to the file to read"
      }
    },
    "required": ["path"]
  }
}
```

## Prompts

Prompts are reusable templates that servers expose for common use cases.

## Sampling

Servers can request that clients perform LLM sampling — asking the host AI to generate text based on provided context. This enables agentic server patterns where the server can leverage AI capabilities.

## Error Handling

Standard JSON-RPC error codes apply. MCP adds domain-specific error codes for protocol-level issues.

## Security Considerations

- Servers should validate all inputs
- Clients should not blindly trust server-provided content
- Transport security (TLS) recommended for remote connections
- Authentication mechanisms: OAuth, API keys, bearer tokens
- Servers should implement rate limiting and access controls

## Official Resources

- Full spec: https://modelcontextprotocol.io/specification/2025-11-25/
- GitHub: https://github.com/modelcontextprotocol/specification
- SDKs: TypeScript, Python, Java, Kotlin, C#
