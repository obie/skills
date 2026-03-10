# Display Configuration

How to customize the visual presentation of activity events — icons, colors, titles, and detail text.

## The DISPLAY Hash

Every action type maps to an icon (Heroicon SVG path) and an accent color (Tailwind class):

```ruby
DISPLAY = {
  "created"              => { icon: "M12 4.5v15m7.5-7.5h-15",           accent: "text-green-400" },
  "updated"              => { icon: "M16.862 4.487l1.687-1.688...",     accent: "text-blue-400" },
  "destroyed"            => { icon: "M14.74 9l-.346 9m-4.788 0...",    accent: "text-red-400" },
  "field_updated"        => { icon: "M16.862 4.487l1.687-1.688...",     accent: "text-amber-400" },
  "status_changed"       => { icon: "M7.5 21L3 16.5m0 0L7.5 12...",   accent: "text-blue-400" },
  "comment_added"        => { icon: "M8.625 12a.375.375 0 11...",      accent: "text-blue-300" },
  "attachment_added"     => { icon: "M18.375 12.739l-7.693...",        accent: "text-amber-400" },
  "attachment_removed"   => { icon: "M18.375 12.739l-7.693...",        accent: "text-red-400" },
  "assigned"             => { icon: "M15.75 6a3.75 3.75 0 11...",     accent: "text-green-400" },
  "unassigned"           => { icon: "M15.75 6a3.75 3.75 0 11...",     accent: "text-gray-400" },
  "relationship_added"   => { icon: "M13.19 8.688a4.5 4.5 0...",      accent: "text-blue-300" },
  "relationship_removed" => { icon: "M13.181 8.68a4.503 4.503...",    accent: "text-red-400" },
  "tag_added"            => { icon: "M9.568 3H5.25A2.25 2.25...",     accent: "text-green-400" },
  "tag_removed"          => { icon: "M9.568 3H5.25A2.25 2.25...",     accent: "text-gray-400" },
}.freeze

DEFAULT_DISPLAY = { icon: "M12 4.5v15m7.5-7.5h-15", accent: "text-gray-400" }.freeze
```

The hash lookup uses `DISPLAY.fetch(action, DEFAULT_DISPLAY)`, so any unrecognized action falls back to a neutral plus icon in gray.

## Adding Custom Actions with Icons

When adding a new action type to your app:

1. Find the right icon from [Heroicons](https://heroicons.com/) (use the "outline" variant, 24x24)
2. Copy the `d` attribute from the SVG `<path>` element
3. Choose an accent color from standard Tailwind classes
4. Add to the `DISPLAY` hash

```ruby
# Example: adding a "published" action
"published" => {
  icon: "M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5M6 7.5h3v3H6v-3z",
  accent: "text-green-400"
}
```

### Recommended color conventions

| Meaning | Tailwind class |
|---------|---------------|
| Created / Added / Positive | `text-green-400` |
| Updated / Changed / Info | `text-blue-400` |
| Warning / Attention | `text-amber-400` |
| Removed / Destroyed / Negative | `text-red-400` |
| Neutral / Inactive | `text-gray-400` |
| Secondary info | `text-blue-300` |

## Display Methods

### `display_icon`

Returns the SVG path string for the action type. Used in the event partial's `<path d="...">` attribute.

```ruby
def display_icon
  display_config[:icon]
end
```

### `display_accent`

Returns the Tailwind color class. Applied to both the SVG icon and the title text for consistent color coding.

```ruby
def display_accent
  display_config[:accent]
end
```

You can override this for conditional coloring. For example, status transitions might use different colors based on the target status:

```ruby
def display_accent
  if action == "status_changed"
    case to_status
    when "active", "published" then "text-green-400"
    when "archived", "cancelled" then "text-red-400"
    when "draft", "paused" then "text-amber-400"
    else "text-blue-400"
    end
  else
    display_config[:accent]
  end
end
```

### `display_title`

Returns the main title text for the event. The default implementation handles common actions:

```ruby
def display_title
  case action
  when "status_changed"
    from_status && to_status ? "#{from_status.capitalize} -> #{to_status.capitalize}" : "Status Changed"
  when "field_updated"
    "Updated #{field_name&.humanize(capitalize: true) || 'Field'}"
  else
    subject_label.present? ? "#{action.titleize}: #{subject_label}" : action.titleize
  end
end
```

Add new cases for custom actions:

```ruby
when "published"     then "Published"
when "approved"      then "Approved by #{user&.name || 'system'}"
when "merged"        then "Merged: #{subject_label}"
```

### `display_detail`

Returns optional secondary text shown below the title. Returns `nil` for actions that don't need extra detail.

```ruby
def display_detail
  case action
  when "status_changed"      then rationale&.truncate(120)
  when "field_updated"       then summary || field_change_summary
  when "comment_added"       then subject_label&.truncate(120)
  when "attachment_added", "attachment_removed"
    subject_label&.truncate(80)
  end
end
```

### `display_badge`

Returns an optional badge label (e.g., the target status for a status change). Returns `nil` when no badge should be shown.

```ruby
def display_badge
  return unless action == "status_changed"
  to_status&.humanize
end
```

To render a badge in the event partial, add this inside the content area:

```erb
<% if event.display_badge %>
  <span class="inline-flex items-center px-1.5 py-px rounded text-[9px] font-semibold uppercase border
    text-gray-500 dark:text-gray-400 border-gray-300 dark:border-gray-600">
    <%= event.display_badge %>
  </span>
<% end %>
```

## Customizing the Event Partial

The default event partial works for most cases, but you can customize it for your app's design system.

### Adding field change links

If `field_updated` events store URLs (e.g., linking to a diff view), create a helper:

```ruby
# app/helpers/activity_events_helper.rb
module ActivityEventsHelper
  def activity_field_change(event)
    from = event.from_field_value
    to = event.to_field_value
    return nil unless from.present? || to.present?

    parts = []
    parts << tag.span(from, class: "text-red-400 line-through") if from.present?
    parts << tag.span("->", class: "text-gray-400 mx-1")
    parts << tag.span(to, class: "text-green-400") if to.present?
    safe_join(parts)
  end
end
```

Then use it in the partial:

```erb
<% if event.action == "field_updated" && event.from_field_value.present? %>
  <p class="text-sm leading-snug mt-1"><%= activity_field_change(event) %></p>
<% elsif event.display_detail.present? %>
  <p class="text-sm text-gray-500 dark:text-gray-400 leading-snug mt-1"><%= event.display_detail %></p>
<% end %>
```

### Adding timestamps with relative time

Replace the absolute date with a relative timestamp:

```erb
<span class="text-[10px] text-gray-400 flex-shrink-0 tabular-nums">
  <%= time_ago_in_words(event.created_at) %> ago
</span>
```

Or show both with a tooltip:

```erb
<span class="text-[10px] text-gray-400 flex-shrink-0 tabular-nums"
      title="<%= event.created_at.strftime("%B %-d, %Y at %-I:%M %p") %>">
  <%= event.created_at.strftime("%-d %b %Y") %>
</span>
```

### Using your own icon system

If you use a different icon library (Lucide, Phosphor, Font Awesome), replace the SVG in the partial with your icon component and change the `DISPLAY` hash values to icon names instead of SVG paths:

```ruby
DISPLAY = {
  "created"  => { icon: "plus", accent: "text-green-400" },
  "updated"  => { icon: "pencil", accent: "text-blue-400" },
  # ...
}.freeze
```

```erb
<%# Using a hypothetical icon component %>
<%= icon(event.display_icon, class: "w-3.5 h-3.5 #{event.display_accent}") %>
```

## Tailwind Safelist

If you use Tailwind JIT and your accent classes only appear in Ruby code (not in templates), they may be purged. Add them to your safelist:

```javascript
// tailwind.config.js
module.exports = {
  safelist: [
    'text-green-400',
    'text-blue-400',
    'text-blue-300',
    'text-amber-400',
    'text-red-400',
    'text-gray-400',
  ],
  // ...
}
```

Alternatively, since the classes appear in the model file, you can add the model to Tailwind's content paths:

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.erb',
    './app/models/activity_event.rb',  // <-- include the model
    // ...
  ],
}
```
