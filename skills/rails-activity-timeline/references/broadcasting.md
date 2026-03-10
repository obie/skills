# Turbo Stream Broadcasting

How `ActivityEvent` broadcasts live updates to connected clients via Action Cable and Turbo Streams.

## Stream Naming Convention

Every trackable model's activity feed has a unique stream name:

```ruby
"#{trackable_type.underscore}_#{trackable_id}_activity"
```

Examples:
- `"project_42_activity"`
- `"article_7_activity"`
- `"post_123_activity"`

The matching target container ID (where new events get prepended) follows the same pattern without the record ID:

```ruby
"#{trackable_type.underscore}_activity"
```

This means all events for a given trackable type share a container ID convention, which works because you only render one timeline per page.

## Broadcast Methods

`ActivityEvent` uses two broadcast callbacks:

### Prepend (new events)

```ruby
after_create_commit :broadcast_activity_prepend

def broadcast_activity_prepend
  return unless trackable

  stream = activity_stream_name
  target = activity_target_id

  # Remove the "no activity" placeholder first
  broadcast_remove_to(stream, target: "no_activity_events")
  # Prepend the new event at the top of the timeline
  broadcast_prepend_to(stream, target: target, partial: broadcast_partial, locals: { event: self })
end
```

### Replace (updated events)

Used when an event is updated after creation — for example, when an AI summary is added to a `field_updated` event:

```ruby
after_update_commit :broadcast_activity_replace

def broadcast_activity_replace
  return unless trackable

  stream = activity_stream_name
  broadcast_replace_to(stream, target: dom_id(self), partial: broadcast_partial, locals: { event: self })
end
```

The `replace` broadcast uses `dom_id(self)` (e.g., `activity_event_42`) to target the specific event element in the DOM.

## Partial Routing

By default, all events use the same partial:

```ruby
def broadcast_partial
  "activity_events/activity_event"
end
```

If different trackable types need different event partials (e.g., a project timeline shows richer detail than a simple post timeline), override with a case statement:

```ruby
def broadcast_partial
  case trackable_type
  when "Project"  then "activity_events/project_activity_event"
  when "Article"  then "activity_events/article_activity_event"
  else "activity_events/activity_event"
  end
end
```

**Why you might need different partials**: Some timelines display extra fields — a project timeline might show assignee avatars and status badges, while a blog post timeline just shows the action and timestamp. Keeping a single partial that conditionally renders everything leads to spaghetti. Better to use focused partials per context.

## Shared Timeline Partial

Create `app/views/shared/_activity_timeline.html.erb`:

```erb
<%# app/views/shared/_activity_timeline.html.erb %>
<%# locals: (record:, max_height: "max-h-96") %>
<% record_type = record.class.name.underscore %>

<div class="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
  <div class="px-5 py-3 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50">
    <h2 class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Activity</h2>
  </div>

  <%= turbo_stream_from "#{record_type}_#{record.id}_activity" %>
  <div id="<%= record_type %>_activity" class="px-5 pt-4 pb-1 <%= max_height %> overflow-y-auto">
    <% record.activity_events.timeline.each do |event| %>
      <%= render "activity_events/activity_event", event: event %>
    <% end %>
    <% if record.activity_events.empty? %>
      <p id="no_activity_events" class="text-xs text-gray-400 italic pb-4">No activity recorded yet.</p>
    <% end %>
  </div>
</div>
```

Key points:
- `turbo_stream_from` subscribes to the Action Cable channel for live updates
- The `id` on the inner `div` must match the `target` in `broadcast_prepend_to`
- The `no_activity_events` element gets removed by the first broadcast prepend
- `max_height` defaults to `max-h-96` (384px) — pass a different Tailwind class to adjust

### Usage in a show view

```erb
<%# app/views/projects/show.html.erb %>
<%= render "shared/activity_timeline", record: @project %>

<%# With custom height %>
<%= render "shared/activity_timeline", record: @project, max_height: "max-h-[600px]" %>
```

## Event Partial

Create `app/views/activity_events/_activity_event.html.erb`:

```erb
<%# app/views/activity_events/_activity_event.html.erb %>
<div id="<%= dom_id(event) %>" class="flex gap-3 group">
  <%# Timeline spine %>
  <div class="flex flex-col items-center w-8 flex-shrink-0">
    <div class="w-7 h-7 rounded-full bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 flex items-center justify-center flex-shrink-0">
      <svg class="w-3.5 h-3.5 <%= event.display_accent %>" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="<%= event.display_icon %>"/>
      </svg>
    </div>
    <div class="w-px flex-1 bg-gray-200 dark:bg-gray-700"></div>
  </div>

  <%# Content %>
  <div class="flex-1 min-w-0 pb-5 pt-1">
    <div class="flex items-baseline justify-between gap-2">
      <span class="text-[11px] font-semibold uppercase tracking-wider <%= event.display_accent %>"><%= event.display_title %></span>
      <span class="text-[10px] text-gray-400 flex-shrink-0 tabular-nums"><%= event.created_at.strftime("%-d %b %Y") %></span>
    </div>
    <% if event.display_detail.present? %>
      <p class="text-sm text-gray-500 dark:text-gray-400 leading-snug mt-1"><%= event.display_detail %></p>
    <% end %>
    <% if event.user %>
      <div class="flex items-center gap-1 mt-1.5">
        <span class="text-[11px] text-gray-400"><%= event.user.try(:display_name) || event.user.try(:name) || event.user.email %></span>
      </div>
    <% end %>
  </div>
</div>
```

### Design notes

- The vertical "spine" (circle + line) creates a connected timeline visual
- Each event has `dom_id(event)` as its `id` — required for the `broadcast_replace_to` to target individual events
- User display falls back through `display_name`, `name`, then `email` to work with any User model
- All colors use standard Tailwind with `dark:` variants for dark mode support
- The `group` class on the outer div enables hover effects if you want to add them (e.g., `group-hover:bg-gray-50`)

## Action Cable Prerequisites

### Rails 7 with Action Cable (Redis)

```yaml
# config/cable.yml
development:
  adapter: redis
  url: redis://localhost:6379/1

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
```

### Rails 8 with Solid Cable

```yaml
# config/cable.yml
development:
  adapter: solid_cable

production:
  adapter: solid_cable
```

Solid Cable stores messages in the database instead of Redis. Run the installer:

```bash
bin/rails solid_cable:install
```

### Either way

Make sure your layout includes the Action Cable JavaScript:

```erb
<%# app/views/layouts/application.html.erb %>
<%= action_cable_meta_tag %>
```

And that `turbo-rails` is properly set up (it handles the Turbo Streams subscription automatically via `turbo_stream_from`).

## Testing Broadcasts

In development, you can verify broadcasts are working by:

1. Opening two browser windows to the same record's show page
2. Creating an event in one window (or via `rails console`)
3. The event should appear in both windows without a page reload

```ruby
# In rails console — create a test event
project = Project.first
ActivityEvent.create!(
  trackable: project,
  action: "comment_added",
  subject_label: "Test broadcast",
  user: User.first
)
```

If the event doesn't appear live, check:
- Action Cable is running (`Started ActionCable` in server logs)
- The `turbo_stream_from` tag is rendered in the page HTML (inspect the DOM)
- The stream name in the tag matches the broadcast stream name
- No JavaScript console errors related to WebSocket connections
