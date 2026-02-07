---
name: mcp-oauth-setup
description: "Implement MCP server authentication with OAuth Dynamic Client Registration (RFC 7591), Authorization Server Metadata Discovery (RFC 8414), and generalized per-agent credential support. This skill should be used when building admin UIs that let users connect to third-party MCP servers, whether they use OAuth (Linear, Sentry, Granola), bearer tokens (Render, custom APIs), or API keys. Covers the full flow: metadata discovery, client registration, PKCE authorization, token exchange, token refresh, tool sync, and credential storage patterns (shared vs per-agent for any auth type). Includes hard-won lessons from production implementation."
---

# MCP Server Authentication & OAuth Dynamic Client Registration

Implement flexible authentication for MCP (Model Context Protocol) server connections.
For OAuth providers, auto-discover endpoints and dynamically register as a client —
the user just provides the MCP server URL and clicks "Connect." For bearer/API key
providers, support both admin-shared and per-agent credentials so different agents
can authenticate with different accounts.

## When to Use

- Building an admin UI for managing MCP server connections
- Integrating with third-party MCP providers (Linear, Sentry, Granola, Render, etc.)
- Implementing the MCP Streamable HTTP transport with authenticated tool sync
- Adding per-agent credential support so each agent can use its own account
- Adding OAuth to an existing MCP connector/server management system

## Core Standards

The OAuth implementation relies on three RFCs:

1. **RFC 8414** - OAuth Authorization Server Metadata Discovery via `.well-known/oauth-authorization-server`
2. **RFC 7591** - Dynamic Client Registration at the provider's registration endpoint
3. **RFC 7636** - PKCE (S256) for authorization code security

**Not all MCP servers use OAuth.** Some (e.g., Render) use bearer tokens with API keys
and handle account/workspace selection at the MCP protocol level. The credential system
must be auth-type-agnostic.

## Architecture Overview

### Credential Mode (Orthogonal to Auth Type)

`credential_mode` applies to **all** auth types (bearer, api_key_header, oauth), not
just OAuth. This is a critical design decision — different agents may need their own
credentials for the same MCP server (e.g., different Render accounts, different Linear
workspaces).

```
credential_mode = "shared"     → Admin provides one credential, all agents use it
credential_mode = "per_agent"  → Each agent has its own credential
```

### OAuth Flow

```
Admin clicks "Connect"
    |
    v
Discover OAuth metadata (RFC 8414)
    |  GET /.well-known/oauth-authorization-server
    v
Register as OAuth client (RFC 7591)
    |  POST /oauth/register
    v
Redirect to provider consent screen
    |  GET /oauth/authorize?client_id=...&code_challenge=...
    v
Provider redirects back with code
    |  GET /callback?code=...&state=...
    v
Exchange code for tokens
    |  POST /oauth/token
    v
Store tokens, sync tools
```

## Implementation Steps

### 1. Database Schema

Create two tables: one for MCP server configuration (including OAuth metadata and shared
tokens), and one for per-agent credentials (works for any auth type).

Refer to `references/schema.md` for complete migration and model setup.

Key design decisions:
- Encrypt all secrets at rest (`encrypts :oauth_client_id`, etc.)
- Store both shared tokens (on the server record) and per-agent tokens (join table)
- Use `credential_mode` (`"shared"` or `"per_agent"`) — applies to ALL auth types, not just OAuth
- Store `discovered_tools` as a JSON array for tool name tracking
- `AgentMcpConnection.access_token` stores OAuth tokens, bearer tokens, or API keys

### 2. OAuth Discovery and Registration

Implement three model methods on the MCP server record. Refer to `references/oauth_flow.md`
for complete implementation code.

**Discovery** (`discover_oauth_metadata!`):
- Derive `.well-known/oauth-authorization-server` URL from the MCP server's host
- Parse the JSON response for `authorization_endpoint`, `token_endpoint`, `registration_endpoint`, `scopes_supported`
- Skip if endpoints are already manually configured
- **Not all servers support this** — handle 404 gracefully

**Registration** (`register_oauth_client!`):
- POST to the registration endpoint with `client_name`, `redirect_uris`, `grant_types`, `response_types`, `token_endpoint_auth_method`
- Store the returned `client_id` and `client_secret`
- Skip if `client_id` is already present

**Combined** (`discover_and_register_oauth!`):
- Run discovery then registration in sequence, skipping either if already configured
- Accept `redirect_uri` parameter for the registration payload

### 3. Authorization Controller

Create an OAuth controller with `authorize` and `callback` actions.
Refer to `references/oauth_flow.md` for the full controller implementation.

Critical pitfalls to avoid:

**Turbo Drive cross-origin redirects**: Standard `redirect_to` with an external URL is
silently swallowed by Turbo Drive because it cannot follow cross-origin 302 redirects. The
browser stays on the current page with no feedback. Render an HTML page with
`<meta http-equiv="refresh" content="0;url=...">` for the external OAuth redirect instead.

**State parameter**: Use a signed, expiring message (e.g., Rails `message_verifier`) containing
the connector ID, PKCE code verifier, optional agent ID, and timestamp. Set 10-minute expiry.

**String keys from message verifier**: After verifying the state token, the payload uses
**string keys** not symbol keys. Access with `payload["connector_id"]`, not `payload[:connector_id]`.

**PKCE (S256)**: Generate a random `code_verifier`, compute `code_challenge` as URL-safe Base64
of SHA-256 digest with no padding. Send challenge in authorize request, verifier in token exchange.

**Error redirects**: When `agent_id` is present in state, redirect errors back to the agent
edit page, not the connectors index. The user initiated from the agent form and should return there.

**Auto-sync on first agent connection**: For per-agent OAuth, the admin may not have their own
account. When the callback stores the first per-agent token, auto-sync tools using that agent's
token if tools haven't been discovered yet.

### 4. Routes

Mount the OAuth authorize as a member action on the connector resource, and the callback
as a standalone route (since it doesn't carry a connector ID — that comes from state).

```ruby
resources :connectors do
  member do
    get "oauth/authorize", to: "mcp_oauth#authorize", as: :mcp_oauth_authorize
  end
end
get "mcp_oauth/callback", to: "mcp_oauth#callback", as: :mcp_oauth_callback
```

Note on Rails route helper naming: A member route `mcp_oauth_authorize` on `resources :connectors`
generates `mcp_oauth_authorize_connector_path(connector)` — the resource name comes **last**.
This is a common source of `NoMethodError` bugs.

### 5. Token Management

Implement token refresh for both shared and per-agent OAuth tokens.
Refer to `references/oauth_flow.md` for the `ensure_token_fresh!` pattern.

- Check expiry with a 5-minute buffer (`token_expires_at < 5.minutes.from_now`)
- Use `with_lock` for thread-safe updates on shared tokens
- Return the appropriate token based on credential mode
- Bearer/API key per-agent tokens are static (no refresh flow needed)

### 6. MCP Tool Sync (Streamable HTTP Protocol)

After connection, sync available tools from the MCP server.
Refer to `references/tool_sync.md` for the complete implementation.

The MCP Streamable HTTP protocol requires a two-step handshake:
1. Send `initialize` JSON-RPC request to get a `Mcp-Session-Id` header
2. Send `tools/list` with the session ID header

Critical details:
- Set `Accept: application/json, text/event-stream` — some servers return 406 without this
- Some servers return SSE format instead of JSON — parse both formats
- The `Mcp-Session-Id` from the initialize response must be included on subsequent requests
- `sync_tools!` must accept an `agent:` parameter for per-agent auth token resolution
- Some servers (e.g., Render) allow unauthenticated tool listing — auth is only needed for tool execution

### 7. UI Considerations

Refer to `references/ui_patterns.md` for form and index view patterns.

**Connector form:**
- `credential_mode` radio (Shared vs Per-agent) applies to ALL auth types, not just OAuth
- When per-agent is selected for bearer/API key, hide the admin token input
- Show OAuth-specific fields (advanced config, Connect button) only for OAuth auth type
- Use Stimulus controller to toggle visibility based on both `auth_type` AND `credential_mode`

**Connectors index:**
- Show "Connect" button only for shared OAuth that isn't connected yet
- Show "Per-agent" label for any per-agent connector (not just OAuth)
- Show "Sync" button for everything else

**Agent edit form — three states for per-agent connectors:**
1. Per-agent OAuth, not connected → grayed card, "Connect" button (OAuth redirect)
2. Per-agent bearer/API key, not connected → card with inline password input for token entry
3. Connected (any type) → normal card with tool checkboxes + "Token configured" badge

## Verified MCP Providers

Tested and confirmed working with:
- **Linear** (`https://mcp.linear.app/mcp`) - 45 tools, SSE response format, OAuth
- **Sentry** (`https://mcp.sentry.dev/mcp`) - 14 tools, standard JSON responses, OAuth
- **Granola** (`https://mcp.granola.ai/mcp`) - 4 tools, standard JSON responses, OAuth
- **Render** (`https://mcp.render.com/mcp`) - 24 tools, bearer token auth (no OAuth), per-agent API keys

## Common Failure Modes

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Page stays on form after create, no redirect | Turbo Drive swallows cross-origin 302 | Use HTML meta refresh instead of `redirect_to` |
| `NoMethodError` on route helper | Wrong helper name ordering | Member route on `:connectors` generates `mcp_oauth_authorize_connector_path` |
| `payload[:connector_id]` returns nil | Message verifier returns string keys | Use `payload["connector_id"]` |
| 406 from MCP server | Missing Accept header | Add `Accept: application/json, text/event-stream` |
| 400 "Mcp-Session-Id required" | Skipped initialize handshake | Send `initialize` first, use returned session ID |
| JSON parse error on tool sync | Server returns SSE format | Detect and parse both `text/event-stream` and JSON |
| Token exchange fails silently | Missing `code_verifier` in token request | Include PKCE verifier from signed state |
| OAuth discovery 404 | MCP server doesn't use OAuth | Use bearer or API key auth instead; not all MCP servers support RFC 8414 |
| Per-agent connector shows no tools | Admin can't sync without a token | Tools auto-sync on first agent connection |
| Error redirect goes to wrong page | `agent_id` not checked in rescue | Redirect to agent edit when `agent_id` present |
