# OAuth Flow Implementation

## OAuth Discovery (RFC 8414)

Fetch the provider's OAuth metadata from its well-known endpoint. The URL is derived
from the MCP server's host (not the full path).

**Important:** Not all MCP servers support OAuth discovery. Some (e.g., Render) return
404. Handle this gracefully — those servers should use bearer or API key auth instead.

```ruby
# On the McpServer model
def discover_oauth_metadata!
  server_uri = URI.parse(url)
  well_known_url = "#{server_uri.scheme}://#{server_uri.host}" \
                   "#{":#{server_uri.port}" unless [80, 443].include?(server_uri.port)}" \
                   "/.well-known/oauth-authorization-server"

  response = Faraday.get(well_known_url)
  raise "OAuth discovery failed (HTTP #{response.status})" unless response.success?

  metadata = JSON.parse(response.body)

  update!(
    oauth_authorization_url: metadata["authorization_endpoint"],
    oauth_token_url: metadata["token_endpoint"],
    oauth_scopes: metadata["scopes_supported"]&.join(" ")
  )

  metadata
end
```

Example `.well-known/oauth-authorization-server` response:

```json
{
  "issuer": "https://mcp.sentry.dev",
  "authorization_endpoint": "https://mcp.sentry.dev/oauth/authorize",
  "token_endpoint": "https://mcp.sentry.dev/oauth/token",
  "registration_endpoint": "https://mcp.sentry.dev/oauth/register",
  "scopes_supported": ["org:read", "project:write", "team:write", "event:write"],
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"]
}
```

## Dynamic Client Registration (RFC 7591)

Register the application as an OAuth client with the provider. This eliminates the need
for manual app registration on the provider's developer portal.

```ruby
# On the McpServer model
def register_oauth_client!(metadata, redirect_uri:)
  registration_endpoint = metadata["registration_endpoint"]
  raise "Server does not support dynamic client registration" unless registration_endpoint.present?

  response = Faraday.post(registration_endpoint) do |req|
    req.headers["Content-Type"] = "application/json"
    req.body = JSON.generate({
      client_name: "MyApp",           # Replace with your application name
      redirect_uris: [redirect_uri],
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      token_endpoint_auth_method: "client_secret_post"
    })
  end

  raise "Client registration failed (HTTP #{response.status})" unless response.success?

  data = JSON.parse(response.body)
  raise "Client registration failed: #{data['error']}" unless data["client_id"]

  update!(
    oauth_client_id: data["client_id"],
    oauth_client_secret: data["client_secret"]
  )

  data
end
```

## Combined Discovery + Registration

Skip discovery if endpoints are manually set. Skip registration if client_id exists.

```ruby
def discover_and_register_oauth!(redirect_uri:)
  if oauth_authorization_url.blank? || oauth_token_url.blank?
    metadata = discover_oauth_metadata!
  else
    metadata = { "registration_endpoint" => nil }
  end
  register_oauth_client!(metadata, redirect_uri: redirect_uri) unless oauth_client_id.present?
end
```

## Authorization Controller

### Authorize Action

```ruby
def authorize
  connector = McpServer.find(params[:id])
  redirect_uri = mcp_oauth_callback_url

  # Auto-discover and register if needed
  connector.discover_and_register_oauth!(redirect_uri: redirect_uri)

  # PKCE: Generate code verifier and S256 challenge
  code_verifier = SecureRandom.urlsafe_base64(32)
  code_challenge = Base64.urlsafe_encode64(
    Digest::SHA256.digest(code_verifier),
    padding: false
  )

  # Build signed state with connector ID, verifier, and optional agent ID
  payload = {
    connector_id: connector.id,
    code_verifier: code_verifier,
    timestamp: Time.current.to_i
  }
  payload[:agent_id] = params[:agent_id].to_i if params[:agent_id].present?

  state = Rails.application.message_verifier(:mcp_oauth).generate(
    payload,
    expires_in: 10.minutes
  )

  url = connector.build_authorize_url(
    state: state,
    redirect_uri: redirect_uri,
    code_challenge: code_challenge
  )

  # CRITICAL: Do NOT use redirect_to for external URLs with Turbo Drive.
  # Turbo cannot follow cross-origin 302 redirects — the browser silently
  # stays on the current page. Use HTML meta refresh instead.
  render html: helpers.tag.html(
    helpers.tag.head(
      helpers.tag.meta("http-equiv": "refresh", content: "0;url=#{url}")
    ) +
    helpers.tag.body(
      "Redirecting to OAuth provider...",
      style: "font-family:system-ui;padding:2rem;color:#666"
    )
  ), layout: false, content_type: "text/html"
rescue => e
  # Redirect back to the page the user came from
  error_redirect = params[:agent_id].present? ? edit_agent_path(params[:agent_id]) : connectors_path
  redirect_to error_redirect, alert: "OAuth setup failed: #{e.message}"
end
```

### Callback Action

```ruby
def callback
  if params[:error].present?
    redirect_to connectors_path, alert: "OAuth cancelled: #{params[:error]}"
    return
  end

  # IMPORTANT: message_verifier.verify returns STRING keys, not symbols
  payload = Rails.application.message_verifier(:mcp_oauth).verify(params[:state])
  connector = McpServer.find(payload["connector_id"])

  token_data = connector.exchange_code_for_token!(
    code: params[:code],
    redirect_uri: mcp_oauth_callback_url,
    code_verifier: payload["code_verifier"]  # String key, not symbol
  )

  if payload["agent_id"]
    # Per-agent token storage
    agent = Agent.find(payload["agent_id"])
    connection = AgentMcpConnection.find_or_initialize_by(
      agent: agent,
      mcp_server: connector
    )
    connection.update!(
      access_token: token_data["access_token"],
      refresh_token: token_data["refresh_token"],
      token_expires_at: token_data["expires_in"] ?
        Time.current + token_data["expires_in"].to_i.seconds : nil
    )

    # Auto-sync tools on first agent connection for per-agent OAuth,
    # using the agent's token since there's no shared admin token.
    if connector.discovered_tools.blank?
      connector.sync_tools!(agent: agent) rescue nil
    end

    redirect_to edit_agent_path(agent), notice: "Connected to #{connector.name}."
  else
    # Shared token storage
    connector.update!(
      oauth_access_token: token_data["access_token"],
      oauth_refresh_token: token_data["refresh_token"],
      oauth_token_expires_at: token_data["expires_in"] ?
        Time.current + token_data["expires_in"].to_i.seconds : nil
    )
    redirect_to edit_connector_path(connector), notice: "Connected to #{connector.name}."
  end
rescue ActiveSupport::MessageVerifier::InvalidSignature
  redirect_to connectors_path, alert: "Invalid or expired OAuth state. Please try again."
end
```

## Build Authorize URL

```ruby
# On the McpServer model
def build_authorize_url(state:, redirect_uri:, code_challenge: nil)
  raise "OAuth not configured" unless oauth_authorization_url.present? && oauth_client_id.present?

  params = {
    response_type: "code",
    client_id: oauth_client_id,
    redirect_uri: redirect_uri,
    state: state
  }
  params[:scope] = oauth_scopes if oauth_scopes.present?
  if code_challenge
    params[:code_challenge] = code_challenge
    params[:code_challenge_method] = "S256"
  end

  "#{oauth_authorization_url}?#{params.to_query}"
end
```

## Token Exchange

```ruby
# On the McpServer model
def exchange_code_for_token!(code:, redirect_uri:, code_verifier: nil)
  raise "OAuth not configured" unless oauth_token_url.present? && oauth_client_id.present?

  body = {
    grant_type: "authorization_code",
    code: code,
    redirect_uri: redirect_uri,
    client_id: oauth_client_id
  }
  body[:client_secret] = oauth_client_secret if oauth_client_secret.present?
  body[:code_verifier] = code_verifier if code_verifier.present?

  response = Faraday.post(oauth_token_url) do |req|
    req.headers["Content-Type"] = "application/x-www-form-urlencoded"
    req.body = URI.encode_www_form(body)
  end

  data = JSON.parse(response.body)
  raise "Token exchange failed: #{data['error_description'] || data['error']}" unless data["access_token"]

  data
end
```

## Token Refresh (Shared)

```ruby
# On the McpServer model
def ensure_token_fresh!
  return unless oauth_token_expiring_soon? && oauth_refresh_token.present?

  body = {
    grant_type: "refresh_token",
    refresh_token: oauth_refresh_token,
    client_id: oauth_client_id
  }
  body[:client_secret] = oauth_client_secret if oauth_client_secret.present?

  response = Faraday.post(oauth_token_url) do |req|
    req.headers["Content-Type"] = "application/x-www-form-urlencoded"
    req.body = URI.encode_www_form(body)
  end

  data = JSON.parse(response.body)
  raise "Token refresh failed" unless data["access_token"]

  with_lock do
    update!(
      oauth_access_token: data["access_token"],
      oauth_refresh_token: data["refresh_token"] || oauth_refresh_token,
      oauth_token_expires_at: data["expires_in"] ?
        Time.current + data["expires_in"].to_i.seconds : nil
    )
  end
end

private

def oauth_token_expiring_soon?
  return false unless oauth_token_expires_at
  oauth_token_expires_at < 5.minutes.from_now
end
```

## Token Resolution (Generalized)

For bearer/API key auth types, resolve per-agent or shared credentials:

```ruby
# On the McpServer model — resolves bearer tokens and API keys
def resolve_auth_token(agent)
  if per_agent_credentials? && agent
    connection = agent_mcp_connections.find_by(agent: agent)
    connection&.access_token  # No refresh needed for static tokens
  else
    resolve_credential(auth_token) if auth_token.present?
  end
end

# Resolves OAuth tokens with refresh support
def resolve_oauth_token(agent)
  if oauth_shared?
    ensure_token_fresh!
    oauth_access_token
  elsif oauth_per_agent? && agent
    connection = agent_mcp_connections.find_by(agent: agent)
    return nil unless connection&.connected?
    connection.ensure_token_fresh!(self)
    connection.access_token
  end
end
```

## Controller: Create Action (Auto-Redirect to OAuth)

When creating a connector with shared OAuth, redirect to the OAuth flow immediately
after save so the admin can authenticate in one step.

```ruby
def create
  @connector = McpServer.new(connector_params)

  if @connector.save
    if @connector.oauth_shared?
      redirect_to mcp_oauth_authorize_connector_path(@connector)
    else
      redirect_to connectors_path, notice: "Connector '#{@connector.name}' created."
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```
