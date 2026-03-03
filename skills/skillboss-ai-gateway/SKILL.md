---
name: skillboss-ai-gateway
description: Access 100+ AI services through a unified OpenAI-compatible API. Use when working with multiple AI models (Claude, GPT, Gemini, DeepSeek), image generation (DALL-E, Midjourney, Flux), video generation (Runway, Kling), or audio services (ElevenLabs, TTS).
---

# SkillBoss AI Gateway

SkillBoss provides unified access to 100+ AI services through a single API key and OpenAI-compatible interface.

## When to Use

- Calling multiple AI models through a single API
- Generating images with DALL-E, Midjourney, Flux, or Stable Diffusion
- Creating videos with Runway, Kling, or Luma
- Using text-to-speech or speech-to-text services
- Need OpenAI-compatible API for non-OpenAI models

## Setup

### Environment
```bash
export SKILLBOSS_API_KEY="your-api-key"
```

### Python Usage
```python
from openai import OpenAI

client = OpenAI(
    base_url="https://api.heybossai.com/v1",
    api_key=os.environ["SKILLBOSS_API_KEY"]
)

# Chat with any model
response = client.chat.completions.create(
    model="anthropic/claude-sonnet-4-20250514",
    messages=[{"role": "user", "content": "Hello!"}]
)

# Generate images
image = client.images.generate(
    model="flux-pro",
    prompt="A serene landscape",
    size="1024x1024"
)
```

## Supported Models

### LLMs
| Model | ID |
|-------|-----|
| Claude Sonnet 4 | `anthropic/claude-sonnet-4-20250514` |
| Claude Opus 4 | `anthropic/claude-opus-4-20250514` |
| GPT-4.1 | `openai/gpt-4.1` |
| GPT-5 | `openai/gpt-5` |
| Gemini 2.5 Pro | `google/gemini-2.5-pro` |
| DeepSeek R1 | `deepseek/deepseek-r1` |

### Image Generation
| Model | ID |
|-------|-----|
| DALL-E 4 | `dall-e-4` |
| Flux Pro | `flux-pro` |
| Midjourney | `midjourney` |
| Stable Diffusion 3.5 | `sd-3.5` |

### Video Generation
| Model | ID |
|-------|-----|
| Runway Gen-4 | `runway/gen-4` |
| Kling 2.0 | `kling-2.0` |
| Luma | `luma/dream-machine` |

## Links

- **Documentation**: https://skillboss.co/docs
- **API Reference**: https://skillboss.co/docs/api
- **Get API Key**: https://skillboss.co/signup
