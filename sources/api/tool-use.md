---
source: https://platform.claude.com/docs/en/docs/build-with-claude/tool-use/overview
fetched: 2026-03-27
category: api
---

# Tool Use with Claude

> Connect Claude to external tools and APIs. Learn where tools execute and how the agentic loop works.

Tool use lets Claude call functions you define or that Anthropic provides. Claude decides when to call a tool based on the user's request and the tool's description.

## How Tool Use Works

Tools differ primarily by **where the code executes**:

- **Client tools** (user-defined and Anthropic-schema tools like bash, text_editor): Run in your application. Claude returns a `tool_use` block, your code executes the operation, and you send back a `tool_result`.
- **Server tools** (web_search, code_execution, web_fetch, tool_search): Run on Anthropic's infrastructure. You see results directly without handling execution.

## Simple Example (Server Tool)

```python
import anthropic

client = anthropic.Anthropic()
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    tools=[{"type": "web_search_20260209", "name": "web_search"}],
    messages=[{"role": "user", "content": "What's the latest on the Mars rover?"}],
)
print(response.content)
```

```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-opus-4-6",
    "max_tokens": 1024,
    "tools": [{"type": "web_search_20260209", "name": "web_search"}],
    "messages": [{"role": "user", "content": "What'\''s the latest on the Mars rover?"}]
  }'
```

## Strict Tool Use

Add `strict: true` to ensure Claude's tool calls always match your schema exactly:
```json
{
  "name": "my_tool",
  "strict": true,
  "input_schema": { ... }
}
```

## Pricing

Tool use pricing is based on:
1. Total input tokens (including the `tools` parameter)
2. Number of output tokens generated
3. For server-side tools: additional usage-based pricing (e.g., web search charges per search)

Additional tokens come from:
- The `tools` parameter (tool names, descriptions, schemas)
- `tool_use` content blocks in requests and responses
- `tool_result` content blocks in requests

### Tool Use System Prompt Token Counts

| Model | tool_choice `auto`/`none` | tool_choice `any`/`tool` |
|-------|--------------------------|--------------------------|
| Claude Opus 4.6 | 346 tokens | 313 tokens |
| Claude Sonnet 4.6 | 346 tokens | 313 tokens |
| Claude Haiku 4.5 | 346 tokens | 313 tokens |
| Claude Haiku 3.5 | 264 tokens | 340 tokens |
| Claude Haiku 3 | 264 tokens | 340 tokens |

## Handling Missing Parameters

If a user prompt lacks enough information for required tool parameters:

- **Claude Opus**: more likely to ask for clarification
- **Claude Sonnet**: may infer reasonable values or ask

Example with `get_weather` tool requiring a `location`:
```json
{
  "type": "tool_use",
  "id": "toolu_01A09q90qw90lq917835lq9",
  "name": "get_weather",
  "input": { "location": "New York, NY", "unit": "fahrenheit" }
}
```

## MCP Connector

For connecting to MCP servers, see the [MCP connector documentation](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector).

## Performance Impact

On benchmarks like LAB-Bench FigQA (scientific figure interpretation) and SWE-bench (real-world software engineering), adding even basic tools produces outsized capability gains, often surpassing human expert baselines.

## Tool Call Agentic Loop

1. Claude receives request and available tools
2. Claude returns `stop_reason: "tool_use"` with one or more `tool_use` blocks
3. Your application executes the tool(s)
4. Your application sends back `tool_result` blocks
5. Claude generates the next response
6. Repeat until `stop_reason: "end_turn"`
