# MCP Tool Sync (Streamable HTTP Protocol)

## Overview

After establishing an OAuth connection, sync the list of available tools from the
MCP server. The MCP Streamable HTTP protocol uses JSON-RPC over HTTP POST and requires
a session initialization handshake before calling any methods.

## Two-Step Handshake

### Step 1: Initialize Session

Send a JSON-RPC `initialize` request. The response includes a `Mcp-Session-Id` header
that must be included on all subsequent requests.

### Step 2: List Tools

Send a JSON-RPC `tools/list` request with the session ID header.

## Implementation

```ruby
def sync_tools!
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 10
  http.read_timeout = 30

  # Get auth headers (includes OAuth Bearer token if connected)
  auth_headers = to_sdk_config["headers"] || {}

  # Step 1: Initialize the MCP session
  init_request = Net::HTTP::Post.new(uri.path.presence || "/")
  init_request["Content-Type"] = "application/json"
  init_request["Accept"] = "application/json, text/event-stream"
  auth_headers.each { |k, v| init_request[k] = v }
  init_request.body = JSON.generate({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "MyApp", version: "1.0" }
    }
  })

  init_response = http.request(init_request)
  raise "HTTP #{init_response.code}: #{init_response.body}" unless init_response.is_a?(Net::HTTPSuccess)

  session_id = init_response["Mcp-Session-Id"]

  # Step 2: List tools using the session
  tools_request = Net::HTTP::Post.new(uri.path.presence || "/")
  tools_request["Content-Type"] = "application/json"
  tools_request["Accept"] = "application/json, text/event-stream"
  tools_request["Mcp-Session-Id"] = session_id if session_id
  auth_headers.each { |k, v| tools_request[k] = v }
  tools_request.body = JSON.generate({
    jsonrpc: "2.0",
    id: 2,
    method: "tools/list",
    params: {}
  })

  response = http.request(tools_request)
  raise "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  data = parse_mcp_response(response)
  tools = data.dig("result", "tools")&.map { |t| t["name"] } || []

  update!(discovered_tools: tools, tools_last_synced_at: Time.current)
  tools
end
```

## SSE Response Parsing

Some MCP servers (notably Linear) return `text/event-stream` format instead of plain JSON.
The response body looks like:

```
event: message
data: {"jsonrpc":"2.0","id":2,"result":{"tools":[...]}}
```

Handle both formats:

```ruby
private

def parse_mcp_response(response)
  body = response.body
  content_type = response["Content-Type"].to_s

  if content_type.include?("text/event-stream") || body.start_with?("event:")
    # Extract JSON from SSE data: lines
    data_lines = body.lines.select { |line| line.start_with?("data:") }
    json_str = data_lines.map { |line| line.sub(/\Adata:\s*/, "").strip }.join
    JSON.parse(json_str)
  else
    JSON.parse(body)
  end
end
```

## Common Errors

### 406 Not Acceptable

```
Client must accept both application/json and text/event-stream
```

**Cause**: Missing or incorrect `Accept` header.
**Fix**: Always set `Accept: application/json, text/event-stream` on every request.

### 400 Bad Request

```
Mcp-Session-Id header is required
```

**Cause**: Skipped the `initialize` handshake or didn't pass the session ID.
**Fix**: Always send `initialize` first and include the returned `Mcp-Session-Id` header.

### JSON Parse Error

```
unexpected character: 'event:'
```

**Cause**: Server returned SSE format but code only handles JSON.
**Fix**: Use the `parse_mcp_response` helper that detects and handles both formats.

## Sync Controller Action

Expose a sync endpoint in the connectors controller:

```ruby
def sync_tools
  @connector = McpServer.find(params[:id])
  tools = @connector.sync_tools!
  redirect_to connectors_path, notice: "Discovered #{tools.size} tools from '#{@connector.name}'."
rescue => e
  redirect_to connectors_path, alert: "Sync failed: #{e.message}"
end
```

Route it as a member POST:

```ruby
resources :connectors do
  member do
    post :sync_tools
  end
end
```
