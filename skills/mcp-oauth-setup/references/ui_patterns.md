# UI Patterns for MCP Connectors

## Connector Form (New/Edit)

### Auth Type Selection

Use a select dropdown for auth type that dynamically shows/hides relevant fields.

```erb
<%%= f.select :auth_type,
  [["None", "no_auth"], ["Bearer Token", "bearer"],
   ["API Key Header", "api_key_header"], ["OAuth", "oauth"]],
  {},
  data: { action: "connector-form#updateAuthFields" } %>
```

### Credential Mode (Auth-Type-Agnostic)

The credential mode radio buttons apply to **all** auth types (bearer, api_key_header,
oauth), not just OAuth. They should appear whenever auth_type is not `no_auth`.

When `per_agent` is selected for bearer/API key, hide the admin token input — the admin
doesn't provide a shared token because each agent will have its own.

```erb
<div data-connector-form-target="credentialModeFields" class="hidden">
  <label>Credential Mode</label>
  <div>
    <label>
      <%%= f.radio_button :credential_mode, "shared",
            data: { action: "connector-form#updateAuthFields" } %>
      <strong>Shared</strong>
      <span>Admin provides credentials, used by all agents</span>
    </label>
    <label>
      <%%= f.radio_button :credential_mode, "per_agent",
            data: { action: "connector-form#updateAuthFields" } %>
      <strong>Per-agent</strong>
      <span>Each agent has its own credentials, configured on the agent edit page</span>
    </label>
  </div>
</div>
```

### Stimulus Controller for Dynamic Fields

The controller must track both `auth_type` and `credential_mode` to determine visibility.
Bearer/API key token inputs are only shown when credential_mode is `shared`.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "bearerFields", "apiKeyFields", "oauthFields",
    "credentialModeFields", "headersContainer"
  ]

  connect() { this.updateAuthFields() }

  updateAuthFields() {
    const authType = this.element.querySelector('[name="mcp_server[auth_type]"]').value
    const isBearer = authType === "bearer"
    const isApiKey = authType === "api_key_header"
    const isOAuth = authType === "oauth"
    const hasAuth = isBearer || isApiKey || isOAuth

    // Credential mode applies to ALL auth types
    const credentialMode = this.element.querySelector(
      '[name="mcp_server[credential_mode]"]:checked'
    )?.value || "shared"
    const isShared = credentialMode === "shared"

    // Show credential mode radio when any auth type is selected
    this.credentialModeFieldsTarget.classList.toggle("hidden", !hasAuth)

    // Bearer/API key fields: only show when shared (per-agent tokens set on agent form)
    this.bearerFieldsTarget.classList.toggle("hidden", !(isBearer && isShared))
    this.apiKeyFieldsTarget.classList.toggle("hidden", !(isApiKey && isShared))
    this.oauthFieldsTarget.classList.toggle("hidden", !isOAuth)

    // Disable inputs in hidden sections so they don't submit empty values
    this.bearerFieldsTarget.querySelectorAll("input").forEach(
      el => el.disabled = !(isBearer && isShared)
    )
    this.apiKeyFieldsTarget.querySelectorAll("input").forEach(
      el => el.disabled = !(isApiKey && isShared)
    )
    this.oauthFieldsTarget.querySelectorAll("input, select").forEach(
      el => el.disabled = !isOAuth
    )
  }
}
```

### OAuth Fields Section

When OAuth is selected, show:
1. Description text referencing RFC 8414 and RFC 7591
2. Expandable "Advanced" section for manual overrides
3. If editing an existing connected OAuth connector, show a green "Connected" badge
4. If editing an existing unconnected OAuth connector, show a "Connect with OAuth" button

Note: Credential mode radios are now in a separate section (shown for all auth types).

```erb
<div data-connector-form-target="oauthFields">
  <p>OAuth endpoints and client credentials are discovered automatically
     from the server URL via RFC 8414 and RFC 7591.</p>

  <!-- Advanced: Manual OAuth config -->
  <details>
    <summary>Advanced - manual OAuth configuration</summary>
    <p>For providers that don't support auto-discovery.</p>
    <%%= f.text_field :oauth_authorization_url, placeholder: "https://provider.com/oauth/authorize" %>
    <%%= f.text_field :oauth_token_url, placeholder: "https://provider.com/oauth/token" %>
    <%%= f.password_field :oauth_client_id, value: "" %>
    <%%= f.password_field :oauth_client_secret, value: "" %>
    <%%= f.text_field :oauth_scopes, placeholder: "read write profile" %>
  </details>

  <!-- Connection status (edit mode only) -->
  <%% if @connector.persisted? && @connector.oauth? %>
    <%% if @connector.oauth_connected? %>
      <span class="badge-green">Connected</span>
    <%% else %>
      <%%= link_to "Connect with OAuth",
            mcp_oauth_authorize_connector_path(@connector) %>
    <%% end %>
  <%% end %>
</div>
```

### Preserving Secrets on Update

When updating a connector, blank password fields should not overwrite existing values:

```ruby
def update
  params_to_apply = connector_params

  %i[auth_token oauth_client_id oauth_client_secret].each do |field|
    params_to_apply = params_to_apply.except(field) if params_to_apply[field].blank?
  end

  if @connector.update(params_to_apply)
    if @connector.oauth_shared? && !@connector.oauth_connected?
      redirect_to mcp_oauth_authorize_connector_path(@connector)
    else
      redirect_to connectors_path, notice: "Connector updated."
    end
  else
    render :edit, status: :unprocessable_entity
  end
end
```

## Connectors Index

### Connect vs Sync Button Logic

Show a "Connect" button for unconnected shared OAuth connectors, a "Per-agent" label for
per-agent connectors (any auth type), and a "Sync" button for everything else.

```erb
<%% if connector.per_agent_credentials? && connector.auth_configured? %>
  <span class="badge-blue">Per-agent</span>
<%% elsif connector.oauth? && !connector.oauth_connected? %>
  <%%= link_to mcp_oauth_authorize_connector_path(connector),
        class: "btn-connect" do %>
    Connect
  <%% end %>
<%% else %>
  <%%= button_to sync_tools_connector_path(connector),
        method: :post, class: "btn-sync" do %>
    Sync
  <%% end %>
<%% end %>
```

### Auth Status Column

Show the authentication status as a badge:

```erb
<%% if connector.oauth? %>
  <%% if connector.oauth_connected? %>
    <span class="badge-green">Configured</span>
  <%% else %>
    <span class="badge-yellow">Not connected</span>
  <%% end %>
<%% elsif connector.auth_configured? %>
  <span class="badge-green">Configured</span>
<%% else %>
  <span class="badge-gray">None</span>
<%% end %>
```

### Tools and Last Synced Columns

Display the number of discovered tools and when they were last synced:

```erb
<td><%%= connector.tools_count %> tools</td>
<td><%%= connector.tools_last_synced_at ? time_ago_in_words(connector.tools_last_synced_at) + " ago" : "Never" %></td>
```

## Agent Edit Form — Per-Agent Credentials

The agent form must handle three distinct states for per-agent connectors:

### State Setup

```erb
<%% connectors.each do |connector| %>
  <%% is_per_agent = connector.per_agent_credentials? && connector.auth_configured? %>
  <%% is_per_agent_oauth = connector.oauth? && is_per_agent %>
  <%% is_per_agent_token = (connector.bearer? || connector.api_key_header?) && is_per_agent %>
  <%% connection = @agent_connections[connector.id] if is_per_agent %>
  <%% connected = is_per_agent ? (connection&.connected? || false) : true %>
```

The `@agent_connections` hash is built in the controller:

```ruby
@agent_connections = AgentMcpConnection.where(agent: @agent)
  .index_by(&:mcp_server_id)
```

### State 1: Per-Agent OAuth, Not Connected

Grayed-out card with "OAuth required" badge and "Connect" button that redirects to the
OAuth authorize flow with `agent_id` in the URL:

```erb
<%% if is_per_agent_oauth && !connected %>
  <div class="card-grayed">
    <span class="badge-yellow">OAuth required</span>
    <%%= link_to "Connect",
          mcp_oauth_authorize_connector_path(connector, agent_id: @agent.id) %>
  </div>
```

### State 2: Per-Agent Bearer/API Key, Not Connected

Card with inline password input for the agent's token:

```erb
<%% elsif is_per_agent_token && !connected %>
  <div class="card-outline">
    <span class="badge-yellow">Token required</span>
    <input type="password"
           name="agent_mcp_tokens[<%%= connector.id %>]"
           placeholder="Enter <%%= connector.bearer? ? 'bearer token' : 'API key' %>"
           autocomplete="off" />
  </div>
```

### State 3: Connected (Any Type)

Normal card with tool checkboxes and appropriate status badge:

```erb
<%% else %>
  <div class="card-connected">
    <%% if is_per_agent_token && connected %>
      <span class="badge-green">Token configured</span>
    <%% end %>

    <!-- Tool checkboxes -->
    <%% connector.discovered_tools&.each do |tool| %>
      <label>
        <%%= check_box_tag "agent[tools][]",
              "mcp__#{connector.server_key}__#{tool}",
              @agent.tools&.include?("mcp__#{connector.server_key}__#{tool}") %>
        <%%= tool %>
      </label>
    <%% end %>

    <!-- Optional: Replace token input for bearer/API key -->
    <%% if is_per_agent_token %>
      <details>
        <summary>Replace token</summary>
        <input type="password"
               name="agent_mcp_tokens[<%%= connector.id %>]"
               placeholder="New token (leave blank to keep current)"
               autocomplete="off" />
      </details>
    <%% end %>
  </div>
<%% end %>
```

### Saving Per-Agent Tokens (Controller)

Process the `agent_mcp_tokens` hash from the form to create/update `AgentMcpConnection`
records:

```ruby
# In the agents controller update action, after saving agent params:
def save_per_agent_tokens
  return unless params[:agent_mcp_tokens].present?

  params[:agent_mcp_tokens].each do |server_id, token|
    next if token.blank?

    connection = AgentMcpConnection.find_or_initialize_by(
      agent: @agent,
      mcp_server_id: server_id
    )
    connection.update!(access_token: token)
  end
end
```

### Filtering Available Tools

When building the list of available tools for an agent, exclude per-agent connectors
that the agent hasn't connected to yet (they have no usable token):

```ruby
def set_available_tools
  @available_tools = McpServer.all.flat_map do |s|
    if s.per_agent_credentials? && s.auth_configured?
      # Only include tools if this agent has a connection
      connection = AgentMcpConnection.find_by(agent: @agent, mcp_server: s)
      connection&.connected? ? s.tool_names : []
    else
      s.tool_names
    end
  end
end
```
