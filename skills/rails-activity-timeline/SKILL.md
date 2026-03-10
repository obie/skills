---
name: rails-activity-timeline
description: Add polymorphic activity timelines with live Turbo Stream updates to any Rails model. Covers migration, model, concern, shared partials, broadcasting, and optional AI-generated change summaries.
---

# Rails Activity Timeline

Add a polymorphic activity timeline with live Turbo Stream updates to any Rails model. Track field changes, status transitions, comments, attachments, and more with configurable icons and colors per action type.

## When to Use This Skill

Invoke this skill when:
- Adding an activity/audit timeline to any Rails model
- Tracking field changes, status transitions, comments, or attachments
- Displaying live-updating activity feeds via Turbo Streams
- Auto-logging lifecycle events on child/associated models
- Building activity feeds with configurable icons and colors

## Architecture Overview

The system is built around four components:

1. **`ActivityEvent` model** (polymorphic) — the core event record
2. **`ActivityTrackable` concern** — auto-logs child model lifecycle events on a parent's timeline
3. **Shared timeline partial** — renders a vertical timeline with Turbo Stream live updates
4. **Display configuration** — icon SVG path + accent color per action type, kept in the model

### Key Associations (on ActivityEvent)

```ruby
belongs_to :trackable, polymorphic: true            # required — parent entity whose timeline this belongs to
belongs_to :subject, polymorphic: true, optional: true  # related entity being acted upon
belongs_to :user, optional: true                     # who performed the action
```

### Generic Action Set

```ruby
ACTIONS = %w[
  created updated destroyed
  field_updated status_changed
  comment_added
  attachment_added attachment_removed
  assigned unassigned
  relationship_added relationship_removed
  tag_added tag_removed
].freeze
```

Add domain-specific actions as needed (e.g., `published`, `approved`, `merged`). Just add them to `ACTIONS` and the `DISPLAY` hash.

## Core Patterns

### 1. Setup from Scratch

Migration, full `ActivityEvent` model, `ActivityTrackable` concern, and prerequisites.

See: `references/setup.md`

### 2. Turbo Stream Broadcasting

Stream naming convention, broadcast methods, partial routing, shared timeline partial, and event partial.

See: `references/broadcasting.md`

### 3. Display Configuration

The `DISPLAY` hash, adding custom actions with icons, display methods, and customizing the event partial.

See: `references/display.md`

### 4. AI Summaries (Optional)

AI-generated change summaries for `field_updated` events with long text changes.

See: `references/ai-summaries.md`

## Adding Timeline to a New Model

Quick step-by-step for adding a timeline to any model (e.g., `Project`, `Article`, `Post`):

### Step 1: Add the association

```ruby
class Project < ApplicationRecord
  has_many :activity_events, as: :trackable, dependent: :destroy
end
```

### Step 2: Add the model type to broadcast routing

In `ActivityEvent#broadcast_activity_prepend`, add your model to the partial routing case statement:

```ruby
def broadcast_partial
  case trackable_type
  when "Project", "Article" then "activity_events/activity_event"
  # Add new types here as needed
  else "activity_events/activity_event"
  end
end
```

### Step 3: Render the shared partial in your show view

```erb
<%# app/views/projects/show.html.erb %>
<%= render "shared/activity_timeline", record: @project %>
```

### Step 4: Create events in controllers or callbacks

```ruby
# In a controller action
ActivityEvent.create!(
  trackable: @project,
  user: current_user,
  action: "status_changed",
  details: { from_status: "draft", to_status: "active", rationale: "Ready for review" }
)

# Or track field changes
if @project.saved_change_to_status?
  ActivityEvent.create!(
    trackable: @project,
    user: current_user,
    action: "field_updated",
    details: {
      field: "status",
      from: @project.status_previously_was,
      to: @project.status
    }
  )
end
```

## ActivityTrackable Concern

For child models that should auto-log events on a parent's timeline, include `ActivityTrackable` and implement the interface:

```ruby
class Comment < ApplicationRecord
  include ActivityTrackable

  def activity_trackable = post       # parent entity whose timeline gets the event
  def activity_action_created = "comment_added"
  def activity_action_destroyed = "comment_removed"
  def activity_label = body.truncate(60)
  def activity_user = user
end
```

```ruby
class Attachment < ApplicationRecord
  include ActivityTrackable

  def activity_trackable = record     # polymorphic parent
  def activity_action_created = "attachment_added"
  def activity_action_destroyed = "attachment_removed"
  def activity_label = filename
  def activity_user = user
end
```

Override `activity_created_details` or `activity_destroyed_details` to store additional metadata:

```ruby
def activity_created_details
  { file_size: byte_size, content_type: content_type }
end
```

## Querying

```ruby
# Recent events on a record's timeline (includes user, limit 50)
@project.activity_events.timeline

# Filter by action type
@project.activity_events.by_type("status_changed")

# Find events related to a specific subject across all timelines
ActivityEvent.where(subject: @task).recent

# Events by a specific user
@project.activity_events.where(user: current_user).recent
```

## Common Pitfalls

1. **Events created with wrong trackable** — events appear on the wrong timeline. Double-check `activity_trackable` returns the parent entity, not `self`.

2. **Missing broadcast partial routing for new trackable types** — if you add a new model type and it uses a different partial, add it to the case statement in `broadcast_partial`. Without this, broadcasts silently fail or render the wrong template.

3. **Forgetting to add new actions to ACTIONS constant and DISPLAY hash** — validation will reject events with unrecognized actions. Always add both the action string to `ACTIONS` and a display entry to `DISPLAY`.

4. **Using `trackable: parent` when you want event on the child's own timeline** — if a model has its own timeline AND appears as a subject on a parent's timeline, you need two separate events or a clear decision about which timeline the event belongs to.

5. **N+1 queries on the timeline** — always use the `.timeline` scope which includes `:user`. If you add other associations to the event partial, add them to the scope.

6. **Turbo Stream not updating** — verify the `turbo_stream_from` tag in your view matches the stream name in the broadcast method. The convention is `"#{record_type}_{id}_activity"`.

## Prerequisites

- Rails 7+ with Turbo (via `turbo-rails` gem)
- Action Cable or Solid Cable (Rails 8) configured
- A `User` model (optional but recommended for attribution)
- Tailwind CSS for the default styling (or adapt the classes to your design system)
