# UI Patterns for MCP OAuth Connectors

## Connector Form (New/Edit)

### Auth Type Selection

Use a select dropdown for auth type that dynamically shows/hides relevant fields.
OAuth fields include credential mode (shared vs per-agent) radio buttons and an
expandable "Advanced" section for manual OAuth configuration.

```erb
<%%= f.select :auth_type,
  [["None", "no_auth"], ["Bearer Token", "bearer"],
   ["API Key Header", "api_key_header"], ["OAuth", "oauth"]],
  {},
  data: { action: "connector-form#updateAuthFields" } %>
```

### Stimulus Controller for Dynamic Fields

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bearerFields", "apiKeyFields", "oauthFields"]

  connect() { this.updateAuthFields() }

  updateAuthFields() {
    const authType = this.element.querySelector('[name="mcp_server[auth_type]"]').value
    const isBearer = authType === "bearer"
    const isApiKey = authType === "api_key_header"
    const isOAuth = authType === "oauth"

    this.bearerFieldsTarget.classList.toggle("hidden", !isBearer)
    this.apiKeyFieldsTarget.classList.toggle("hidden", !isApiKey)
    this.oauthFieldsTarget.classList.toggle("hidden", !isOAuth)

    // Disable inputs in hidden sections so they don't submit empty values
    this.bearerFieldsTarget.querySelectorAll("input").forEach(el => el.disabled = !isBearer)
    this.apiKeyFieldsTarget.querySelectorAll("input").forEach(el => el.disabled = !isApiKey)
    this.oauthFieldsTarget.querySelectorAll("input, select").forEach(el => el.disabled = !isOAuth)
  }
}
```

### OAuth Fields Section

When OAuth is selected, show:
1. Description text referencing RFC 8414 and RFC 7591
2. Credential mode radio buttons (Shared vs Per-agent)
3. Expandable "Advanced" section for manual overrides
4. If editing an existing connected OAuth connector, show a green "Connected" badge
5. If editing an existing unconnected OAuth connector, show a "Connect with OAuth" button

```erb
<div data-connector-form-target="oauthFields">
  <p>OAuth endpoints and client credentials are discovered automatically
     from the server URL via RFC 8414 and RFC 7591.</p>

  <!-- Credential Mode -->
  <div>
    <label>
      <%%= f.radio_button :oauth_credential_mode, "shared" %>
      <strong>Shared</strong>
      <span>Admin authenticates once, token shared by all agents</span>
    </label>
    <label>
      <%%= f.radio_button :oauth_credential_mode, "per_agent" %>
      <strong>Per-agent</strong>
      <span>Each agent author must authenticate individually</span>
    </label>
  </div>

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

Show a "Connect" button for unconnected OAuth connectors and a "Sync" button for
connected ones or non-OAuth connectors.

```erb
<%% if connector.oauth? && !connector.oauth_connected? %>
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
