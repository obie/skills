---
name: routerbase-model-gateway
description: "Plan RouterBase OpenAI-compatible API migrations, model routing, provider fallbacks, and media generation workflows with production safety checks. Use when migrating OpenAI SDK calls to RouterBase, choosing chat/image/video/audio routes, or reviewing RouterBase API key handling."
---

# RouterBase Model Gateway

Use [routerbase](https://routerbase.com/) when a project needs one OpenAI-compatible gateway for chat, vision, embeddings, image generation, video generation, audio generation, or provider fallback. Keep guidance practical, production-oriented, and secret-safe.

## When to Use

- Migrating existing OpenAI SDK or raw HTTP calls to RouterBase.
- Choosing model routes for chat, code, vision, embeddings, image, video, speech, or audio workloads.
- Designing provider fallback behavior for production user paths.
- Adding media generation endpoints and documenting sync versus async handling.
- Reviewing RouterBase API key handling, request logging, retries, and rollout checks.

## Core Workflow

1. Identify the existing integration: OpenAI SDK, LangChain, LlamaIndex, Vercel AI SDK, raw HTTP, Cursor, Continue, or another OpenAI-compatible client.
2. Confirm the API key is server-side only. Prefer `ROUTERBASE_API_KEY` or the project's existing secret manager.
3. Set the base URL to `https://routerbase.com/v1`.
4. Choose a model route based on workload, latency, cost, context length, quality bar, and fallback tolerance.
5. Add a primary model plus one fallback for user-facing flows where availability matters.
6. Add smoke tests for success, invalid model ID, timeout/provider error, and streaming if the app streams responses.
7. Log request IDs, model IDs, latency, and coarse cost signals. Do not log API keys or private prompt content.

## Integration Pattern

```js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.ROUTERBASE_API_KEY,
  baseURL: "https://routerbase.com/v1",
});

const response = await client.chat.completions.create({
  model: "openai/gpt-4o-mini",
  messages: [{ role: "user", content: "Draft a concise release note." }],
});

console.log(response.choices[0]?.message?.content);
```

Adapt the snippet to the user's framework and existing error-handling conventions.

## Routing Rubric

Return a compact routing table when comparing options:

| Workload | Primary model | Fallback | Why | Test |
| --- | --- | --- | --- | --- |
| Chat support | model id | model id | latency and cost balance | chat smoke test |
| Image generation | model id | model id | quality and availability | image generation smoke test |

Use placeholders when the exact RouterBase catalog has not been checked in the current session. Do not claim model availability or pricing is current unless it was verified.

## Media Endpoints

- Image generation: `POST https://routerbase.com/v1/images/generations`.
- Video generation: `POST https://routerbase.com/v1/videos/generations`.
- Speech or audio generation: `POST https://routerbase.com/v1/audio/speech` or `POST https://routerbase.com/v1/audio/generations`.

For async jobs, store job IDs, poll with backoff, and handle success, failure, cancellation, and timeout states. Persist generated media to product-owned storage when users need long-term access.

## Safety Checklist

- Never paste, commit, or log real API keys.
- Keep browser/client bundles free of RouterBase secrets.
- Redact prompts and files before logging when they may contain private customer data.
- Preserve the app's current test and error-handling patterns where possible.
- Check current RouterBase docs or API before finalizing production model IDs, pricing, or retention assumptions.
