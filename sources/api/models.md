---
source: https://platform.claude.com/docs/en/docs/about-claude/models
fetched: 2026-03-27
category: api
---

# Models Overview

Claude is a family of state-of-the-art large language models developed by Anthropic.

## Latest Models

| Feature | Claude Opus 4.6 | Claude Sonnet 4.6 | Claude Haiku 4.5 |
|:--------|:----------------|:------------------|:-----------------|
| **Description** | Most intelligent model for building agents and coding | Best combination of speed and intelligence | Fastest model with near-frontier intelligence |
| **Claude API ID** | `claude-opus-4-6` | `claude-sonnet-4-6` | `claude-haiku-4-5-20251001` |
| **Claude API alias** | `claude-opus-4-6` | `claude-sonnet-4-6` | `claude-haiku-4-5` |
| **AWS Bedrock ID** | `anthropic.claude-opus-4-6-v1` | `anthropic.claude-sonnet-4-6` | `anthropic.claude-haiku-4-5-20251001-v1:0` |
| **GCP Vertex AI ID** | `claude-opus-4-6` | `claude-sonnet-4-6` | `claude-haiku-4-5@20251001` |
| **Input pricing** | $5 / MTok | $3 / MTok | $1 / MTok |
| **Output pricing** | $25 / MTok | $15 / MTok | $5 / MTok |
| **Extended thinking** | Yes | Yes | Yes |
| **Adaptive thinking** | Yes | Yes | No |
| **Priority Tier** | Yes | Yes | Yes |
| **Comparative latency** | Moderate | Fast | Fastest |
| **Context window** | 1M tokens (~750k words) | 1M tokens (~750k words) | 200k tokens (~150k words) |
| **Max output** | 128k tokens | 64k tokens | 64k tokens |
| **Reliable knowledge cutoff** | May 2025 | Aug 2025 | Feb 2025 |
| **Training data cutoff** | Aug 2025 | Jan 2026 | Jul 2025 |

Note: Reliable knowledge cutoff = date through which model's knowledge is most extensive. Training data cutoff = broader date range of training data.

## Choosing a Model

- **Claude Opus 4.6**: Most complex tasks, best reasoning and coding capability
- **Claude Sonnet 4.6**: Best balance of speed and intelligence, recommended for most use cases
- **Claude Haiku 4.5**: Fastest, use for high-volume, latency-sensitive applications

All current models support: text and image input, text output, multilingual capabilities, vision.

Available via: Claude API, AWS Bedrock, Google Vertex AI.

## Legacy Models

| Feature | Claude Sonnet 4.5 | Claude Opus 4.5 | Claude Opus 4.1 | Claude Sonnet 4 | Claude Opus 4 | Claude Haiku 3 |
|:--------|:------------------|:----------------|:----------------|:----------------|:--------------|:--------------|
| **Claude API ID** | `claude-sonnet-4-5-20250929` | `claude-opus-4-5-20251101` | `claude-opus-4-1-20250805` | `claude-sonnet-4-20250514` | `claude-opus-4-20250514` | `claude-3-haiku-20240307` |
| **API alias** | `claude-sonnet-4-5` | `claude-opus-4-5` | `claude-opus-4-1` | `claude-sonnet-4-0` | `claude-opus-4-0` | N/A |
| **Input pricing** | $3/MTok | $5/MTok | $15/MTok | $3/MTok | $15/MTok | $0.25/MTok |
| **Output pricing** | $15/MTok | $25/MTok | $75/MTok | $15/MTok | $75/MTok | $1.25/MTok |
| **Context window** | 1M (or 200k) | 200k | 200k | 1M (or 200k) | 200k | 200k |
| **Max output** | 64k | 64k | 32k | 64k | 32k | 4k |
| **Status** | Available | Available | Available | Available | Available | **DEPRECATED** |

**Warning**: Claude Haiku 3 (`claude-3-haiku-20240307`) is deprecated and will retire on **April 19, 2026**. Migrate to Claude Haiku 4.5 before that date.

### Long Context (1M tokens) for Legacy Models

Claude Sonnet 4.5 and Sonnet 4 default to 200k context but can access 1M by including the `context-1m-2025-08-07` beta header. Long context pricing applies to requests exceeding 200k tokens.

## Migration to Claude 4.6

See [Migrating to Claude 4.6](https://platform.claude.com/docs/en/about-claude/models/migration-guide) for detailed instructions.

## Model Availability

All models available via:
- Anthropic Claude API (`api.anthropic.com`)
- AWS Bedrock (with `anthropic.` prefix)
- Google Cloud Vertex AI
- Microsoft Azure AI (Claude on Azure)

## Query Models Programmatically

```bash
GET https://api.anthropic.com/v1/models
```

Returns `max_input_tokens`, `max_tokens`, and `capabilities` object for every available model.

## Performance Highlights (Claude 4)

- Top-tier results in reasoning, coding, multilingual tasks, long-context handling, honesty, and image processing
- Industry-leading agentic coding and computer use capabilities
- Exceptional performance in coding and reasoning
