---
source: https://platform.claude.com/docs/en/api/getting-started
fetched: 2026-03-27
category: api
---

# Claude API Overview

The Claude API is a RESTful API at `https://api.anthropic.com` providing programmatic access to Claude models. The primary API is the Messages API (`POST /v1/messages`).

## Prerequisites

- An [Anthropic Console account](https://platform.claude.com)
- An [API key](https://platform.claude.com/settings/keys)

## Authentication

All requests must include these headers:

| Header | Value | Required |
|--------|-------|----------|
| `x-api-key` | Your API key from Console | Yes |
| `anthropic-version` | API version (e.g., `2023-06-01`) | Yes |
| `content-type` | `application/json` | Yes |

SDKs handle these headers automatically.

### Getting API Keys

1. Create an account at [platform.claude.com](https://platform.claude.com)
2. Go to [Account Settings → Keys](https://platform.claude.com/settings/keys)
3. Generate an API key
4. Use [Workbench](https://platform.claude.com/workbench) to test in the browser

Use workspaces to segment API keys and control spend by use case.

## Available APIs

### General Availability

- **Messages API**: `POST /v1/messages` — Conversational interactions
- **Message Batches API**: `POST /v1/messages/batches` — Process large volumes asynchronously with 50% cost reduction
- **Token Counting API**: `POST /v1/messages/count_tokens` — Count tokens before sending
- **Models API**: `GET /v1/models` — List available models and details

### Beta

- **Files API**: `POST /v1/files`, `GET /v1/files` — Upload and manage files for use across multiple API calls
- **Skills API**: `POST /v1/skills`, `GET /v1/skills` — Create and manage custom agent skills

For beta features, see [Beta headers documentation](https://platform.claude.com/docs/en/api/beta-headers).

## Basic Example (curl)

```bash
curl https://api.anthropic.com/v1/messages \
  --header "x-api-key: $ANTHROPIC_API_KEY" \
  --header "anthropic-version: 2023-06-01" \
  --header "content-type: application/json" \
  --data '{
    "model": "claude-opus-4-6",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Hello, Claude"}
    ]
  }'
```

**Response:**
```json
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hello! How can I assist you today?"
    }
  ],
  "model": "claude-opus-4-6",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 12,
    "output_tokens": 8
  }
}
```

## Client SDKs

Official SDKs available for:
- **Python**: `pip install anthropic`
- **TypeScript/JavaScript**: `npm install @anthropic-ai/sdk`
- **Java**
- **Go**
- **C#**
- **Ruby**
- **PHP**

**Python example:**
```python
from anthropic import Anthropic

client = Anthropic()  # Reads ANTHROPIC_API_KEY from environment
message = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello, Claude"}],
)
print(message.content)
```

**TypeScript example:**
```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();
const message = await client.messages.create({
  model: "claude-opus-4-6",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Hello, Claude" }],
});
console.log(message.content);
```

SDK benefits:
- Automatic header management
- Type-safe request and response handling
- Built-in retry logic and error handling
- Streaming support
- Request timeouts and connection management

## Request Size Limits

| Endpoint | Maximum Size |
|----------|--------------|
| Standard endpoints (Messages, Token Counting) | 32 MB |
| Batch API | 256 MB |
| Files API | 500 MB |

Note: Vertex AI limits requests to 30 MB, Bedrock to 20 MB.

## Response Headers

Every response includes:
- `request-id`: Globally unique request identifier
- `anthropic-organization-id`: Organization ID for the API key used

## Rate Limits

Rate limits are organized into usage tiers that increase automatically as you use the API. Each tier has:
- **Spend limits**: Maximum monthly cost
- **Rate limits**: RPM (requests per minute) and TPM (tokens per minute)

View your limits at [Console → Limits](https://platform.claude.com/settings/limits). For higher limits or Priority Tier, contact sales through Console.

## Third-Party Platforms

| Platform | Provider | Best for |
|----------|----------|---------|
| Amazon Bedrock | AWS | Existing AWS infrastructure, AWS billing |
| Vertex AI | Google Cloud | GCP infrastructure, GCP billing |
| Azure AI | Microsoft Azure | Azure infrastructure, Azure billing |

Third-party platforms may have feature delays or differences. Direct Claude API has features first.

## Data Residency

The Messages API supports optional `inference_geo` parameter to specify where model inference runs.

## Available Regions

Claude API is available in many countries and regions. See [supported regions documentation](https://platform.claude.com/docs/en/api/supported-regions).
