# Claude Code Skills by Obie

Production-ready skills for enhanced Claude Code development workflows.

## Installation

Add this marketplace to your Claude Code:

```shell
/plugin marketplace add obie/skills
```

Then install individual skills:

```shell
/plugin install better-stimulus@obie-skills
```

## Available Skills

### Better Stimulus

Apply opinionated best practices from [betterstimulus.com](https://betterstimulus.com/) when writing or refactoring Stimulus controllers.

**When to use:**
- Writing new Stimulus controllers
- Refactoring existing Stimulus code
- Reviewing Stimulus controller architecture
- Debugging inter-controller communication

**Key patterns:**
- Values API for reactive state management
- Static classes for configurable CSS
- Single Responsibility Principle
- Minimal connect() usage
- Declarative event registration

**Invoke with:** `/better-stimulus` or Claude invokes automatically when working with Stimulus code

### MCP OAuth Setup

Implement zero-configuration OAuth for MCP (Model Context Protocol) server connections using Dynamic Client Registration (RFC 7591) and Authorization Server Metadata Discovery (RFC 8414). Battle-tested with Linear, Sentry, and Granola.

**When to use:**
- Building admin UIs for managing MCP server connections with OAuth
- Integrating with third-party MCP providers
- Implementing MCP Streamable HTTP transport with authenticated tool sync
- Adding OAuth to an existing MCP connector management system

**What it covers:**
- RFC 8414 metadata discovery + RFC 7591 dynamic client registration
- PKCE (S256) authorization flow with signed state
- Token exchange, storage, and refresh (shared + per-agent modes)
- MCP Streamable HTTP tool sync (session handshake, SSE parsing)
- UI patterns (Stimulus forms, Connect vs Sync logic)
- Common failure modes and fixes (Turbo Drive, route helpers, SSE)

**Invoke with:** `/mcp-oauth-setup` or Claude invokes automatically when implementing MCP OAuth

### RouterBase Model Gateway

Plan OpenAI-compatible API migrations, model routing, provider fallbacks, and media generation workflows through [routerbase](https://routerbase.com/).

**When to use:**
- Migrating existing OpenAI SDK code to RouterBase
- Choosing chat, image, video, audio, or embedding model routes
- Designing provider fallback behavior for production paths
- Reviewing RouterBase API key handling, request logging, retries, and rollout checks

**What it covers:**
- Base URL migration to `https://routerbase.com/v1`
- Model routing rubric for latency, budget, quality, context, and fallback tolerance
- Media endpoint guidance for image, video, speech, and audio generation
- Secret handling and privacy guardrails for production applications

**Invoke with:** `/routerbase-model-gateway` or Claude invokes automatically when planning RouterBase integrations

## How It Works

Skills are stored in `skills/<skill-name>/SKILL.md` format. Each skill:
- Contains YAML frontmatter describing when to use it
- Includes comprehensive instructions for Claude
- May reference supporting documentation files
- Can be invoked manually with `/skill-name` or automatically by Claude

## Contributing

Want to add your own skills to this marketplace?

1. Fork this repository
2. Create a new skill directory under `skills/`
3. Write your `SKILL.md` following the [Agent Skills standard](https://agentskills.io)
4. Add an entry to `.claude-plugin/marketplace.json`
5. Submit a pull request

## License

MIT - See LICENSE file for details
