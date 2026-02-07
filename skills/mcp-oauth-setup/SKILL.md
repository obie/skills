---
name: mcp-oauth-setup
description: "Implement OAuth Dynamic Client Registration (RFC 7591) with Authorization Server Metadata Discovery (RFC 8414) for MCP server connections in web applications. This skill should be used when building admin UIs that let users connect to third-party MCP servers requiring OAuth, such as Linear, Sentry, Granola, or any MCP provider supporting the Streamable HTTP transport with OAuth. Covers the full flow: metadata discovery, client registration, PKCE authorization, token exchange, token refresh, tool sync, and credential storage patterns (shared vs per-agent). Includes hard-won lessons from production implementation."
---

# MCP OAuth Dynamic Client Registration

Implement zero-configuration OAuth for MCP (Model Context Protocol) server connections.
Instead of requiring users to manually register OAuth apps and paste client IDs/secrets,
auto-discover OAuth endpoints and dynamically register as a client. The user just provides
the MCP server URL and clicks "Connect."

## When to Use

- Building an admin UI for managing MCP server connections with OAuth
- Integrating with third-party MCP providers (Linear, Sentry, Granola, etc.)
- Implementing the MCP Streamable HTTP transport with authenticated tool sync
- Adding OAuth to an existing MCP connector/server management system

## Core Standards

The implementation relies on three RFCs:

1. **RFC 8414** - OAuth Authorization Server Metadata Discovery via `.well-known/oauth-authorization-server`
2. **RFC 7591** - Dynamic Client Registration at the provider's registration endpoint
3. **RFC 7636** - PKCE (S256) for authorization code security

## Architecture Overview

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
tokens), and one for per-agent tokens when each agent needs its own credential.

Refer to `references/schema.md` for complete migration and model setup.

Key design decisions:
- Encrypt all secrets at rest (`encrypts :oauth_client_id`, etc.)
- Store both shared tokens (on the server record) and per-agent tokens (join table)
- Use `oauth_credential_mode` (`"shared"` or `"per_agent"`) to support both patterns
- Store `discovered_tools` as a JSON array for tool name tracking

### 2. OAuth Discovery and Registration

Implement three model methods on the MCP server record. Refer to `references/oauth_flow.md`
for complete implementation code.

**Discovery** (`discover_oauth_metadata!`):
- Derive `.well-known/oauth-authorization-server` URL from the MCP server's host
- Parse the JSON response for `authorization_endpoint`, `token_endpoint`, `registration_endpoint`, `scopes_supported`
- Skip if endpoints are already manually configured

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

Implement token refresh for both shared and per-agent tokens.
Refer to `references/oauth_flow.md` for the `ensure_token_fresh!` pattern.

- Check expiry with a 5-minute buffer (`token_expires_at < 5.minutes.from_now`)
- Use `with_lock` for thread-safe updates on shared tokens
- Return the appropriate token based on credential mode

### 6. MCP Tool Sync (Streamable HTTP Protocol)

After OAuth connection, sync available tools from the MCP server.
Refer to `references/tool_sync.md` for the complete implementation.

The MCP Streamable HTTP protocol requires a two-step handshake:
1. Send `initialize` JSON-RPC request to get a `Mcp-Session-Id` header
2. Send `tools/list` with the session ID header

Critical details:
- Set `Accept: application/json, text/event-stream` — some servers return 406 without this
- Some servers return SSE format instead of JSON — parse both formats
- The `Mcp-Session-Id` from the initialize response must be included on subsequent requests

### 7. UI Considerations

Refer to `references/ui_patterns.md` for form and index view patterns.

- Show "Connect" button for unconnected OAuth connectors, not "Sync"
- Show "Sync" button only when OAuth token is present
- On create with shared OAuth, auto-redirect to the OAuth flow
- Use dynamic form with Stimulus controller for auth type field visibility
- Show "Connected" badge when token exists
- Provide "Advanced" section for manual OAuth configuration overrides

## Verified MCP Providers

Tested and confirmed working with:
- **Linear** (`https://mcp.linear.app/mcp`) - 45 tools, SSE response format
- **Sentry** (`https://mcp.sentry.dev/mcp`) - 14 tools, standard JSON responses
- **Granola** (`https://mcp.granola.ai/mcp`) - 4 tools, standard JSON responses

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
