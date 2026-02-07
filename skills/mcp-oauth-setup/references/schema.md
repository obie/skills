# Database Schema for MCP Authentication

## MCP Servers Table

The primary table stores MCP server configuration, OAuth metadata from discovery,
dynamically registered client credentials, and shared tokens.

### Migration

```ruby
class CreateMcpServers < ActiveRecord::Migration
  def change
    create_table :mcp_servers do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :auth_type, null: false, default: "none"
      t.string :auth_token                  # Bearer token or API key (shared mode)
      t.string :auth_header_name            # Custom header name for API key auth
      t.jsonb :custom_headers, default: {}
      t.jsonb :discovered_tools, default: []
      t.datetime :tools_last_synced_at

      # Credential mode: applies to ALL auth types, not just OAuth
      t.string :credential_mode, default: "shared"  # "shared" or "per_agent"

      # OAuth fields (populated by discovery + registration)
      t.string :oauth_authorization_url     # From RFC 8414 discovery
      t.string :oauth_token_url             # From RFC 8414 discovery
      t.string :oauth_client_id             # From RFC 7591 registration
      t.string :oauth_client_secret         # From RFC 7591 registration
      t.string :oauth_scopes                # Space-separated, from discovery
      t.string :oauth_access_token          # Shared token (when mode = shared)
      t.string :oauth_refresh_token         # Shared refresh token
      t.datetime :oauth_token_expires_at    # Shared token expiry

      t.timestamps
    end

    add_index :mcp_servers, :name, unique: true
  end
end
```

## Agent MCP Connections Table (Per-Agent Credentials)

When `credential_mode` is `"per_agent"`, each agent stores its own credential
in this join table. The `access_token` field stores OAuth tokens, bearer tokens,
or API keys depending on the connector's auth_type.

```ruby
class CreateAgentMcpConnections < ActiveRecord::Migration
  def change
    create_table :agent_mcp_connections do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :mcp_server, null: false, foreign_key: true
      t.string :access_token          # Per-agent credential (any auth type)
      t.string :refresh_token         # OAuth-specific
      t.datetime :token_expires_at    # OAuth-specific
      t.timestamps
    end

    add_index :agent_mcp_connections,
              [:agent_id, :mcp_server_id],
              unique: true
  end
end
```

## Model: McpServer

```ruby
class McpServer < ApplicationRecord
  # Encrypt all secrets at rest
  encrypts :auth_token
  encrypts :oauth_client_id
  encrypts :oauth_client_secret
  encrypts :oauth_access_token
  encrypts :oauth_refresh_token

  enum :auth_type, {
    no_auth: "none",
    bearer: "bearer",
    api_key_header: "api_key_header",
    oauth: "oauth"
  }

  has_many :agent_mcp_connections, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true,
            format: { with: /\Ahttps?:\/\/.+/i, message: "must be an HTTP(S) URL" }
  validates :auth_header_name, presence: true, if: :api_key_header?
  # credential_mode validates for ALL auth types, not just OAuth
  validates :credential_mode,
            inclusion: { in: %w[shared per_agent] }, if: :auth_configured?

  # General credential mode helpers (auth-type-agnostic)
  def shared_credentials?
    credential_mode == "shared"
  end

  def per_agent_credentials?
    credential_mode == "per_agent"
  end

  # OAuth-specific wrappers (check auth_type too)
  def oauth_shared?
    oauth? && shared_credentials?
  end

  def oauth_per_agent?
    oauth? && per_agent_credentials?
  end

  def oauth_connected?
    oauth? && oauth_access_token.present?
  end

  def auth_configured?
    !no_auth?
  end

  # Generate MCP tool names in the mcp__<server_key>__<tool> format
  def tool_names
    (discovered_tools || []).map { |tool| "mcp__#{server_key}__#{tool}" }
  end

  def server_key
    name.downcase.gsub(/[^a-z0-9]/, "_")
  end

  # Build the SDK config hash for Claude CLI's .mcp.json
  def to_sdk_config(agent: nil)
    config = { "type" => "http", "url" => url }
    headers = (custom_headers || {}).dup

    case auth_type
    when "bearer"
      token = resolve_auth_token(agent)
      headers["Authorization"] = "Bearer #{token}" if token.present?
    when "api_key_header"
      token = resolve_auth_token(agent)
      headers[auth_header_name] = token if token.present?
    when "oauth"
      token = resolve_oauth_token(agent)
      headers["Authorization"] = "Bearer #{token}" if token
    end

    config["headers"] = headers if headers.any?
    config
  end

  private

  # Resolve bearer/API key token — checks per-agent first, falls back to shared
  def resolve_auth_token(agent)
    if per_agent_credentials? && agent
      connection = agent_mcp_connections.find_by(agent: agent)
      connection&.access_token
    else
      resolve_credential(auth_token) if auth_token.present?
    end
  end
end
```

## Model: AgentMcpConnection

```ruby
class AgentMcpConnection < ApplicationRecord
  encrypts :access_token
  encrypts :refresh_token

  belongs_to :agent
  belongs_to :mcp_server

  validates :agent_id, uniqueness: { scope: :mcp_server_id }

  def connected?
    access_token.present?
  end

  def token_expiring_soon?
    return false unless token_expires_at
    token_expires_at < 5.minutes.from_now
  end

  # Only needed for OAuth per-agent tokens (bearer/API key tokens don't expire)
  def ensure_token_fresh!(mcp_server)
    return unless token_expiring_soon? && refresh_token.present?

    response = Faraday.post(mcp_server.oauth_token_url) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: mcp_server.oauth_client_id,
        client_secret: mcp_server.oauth_client_secret
      )
    end

    data = JSON.parse(response.body)
    raise "Token refresh failed" unless data["access_token"]

    with_lock do
      update!(
        access_token: data["access_token"],
        refresh_token: data["refresh_token"] || refresh_token,
        token_expires_at: data["expires_in"] ? Time.current + data["expires_in"].to_i.seconds : nil
      )
    end
  end
end
```
