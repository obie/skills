# Setup from Scratch

Complete guide to adding the activity timeline system to a Rails 7+/8+ application.

## Prerequisites

- Rails 7+ with `turbo-rails` gem installed
- Action Cable configured (or Solid Cable on Rails 8)
- Tailwind CSS (for default styling; adapt classes for other frameworks)
- A `User` model (optional — events can be anonymous)

## Migration

Generate and run the migration:

```bash
bin/rails generate migration CreateActivityEvents
```

```ruby
class CreateActivityEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_events do |t|
      t.references :trackable, polymorphic: true, null: false
      t.references :subject, polymorphic: true
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :subject_label
      t.jsonb :details, default: {}
      t.timestamps
    end

    add_index :activity_events, [:trackable_type, :trackable_id, :created_at],
              name: "index_activity_events_on_trackable_and_created_at"
    add_index :activity_events, [:subject_type, :subject_id]
    add_index :activity_events, :action
  end
end
```

Key design decisions:
- `trackable` is **required** — every event must belong to a parent entity's timeline
- `subject` is **optional** — used when the event is _about_ a related entity (e.g., a comment added to a project)
- `subject_label` stores a human-readable label snapshotted at creation time, so it survives if the subject is later deleted
- `details` is JSONB for flexible metadata (field changes, status transitions, etc.)
- The composite index on `(trackable_type, trackable_id, created_at)` is critical for the `timeline` scope performance

## ActivityEvent Model

Create `app/models/activity_event.rb`:

```ruby
# frozen_string_literal: true

class ActivityEvent < ApplicationRecord
  ACTIONS = %w[
    created updated destroyed
    field_updated status_changed
    comment_added
    attachment_added attachment_removed
    assigned unassigned
    relationship_added relationship_removed
    tag_added tag_removed
  ].freeze

  include Turbo::Broadcastable
  include ActionView::RecordIdentifier

  belongs_to :trackable, polymorphic: true
  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }

  after_create_commit :broadcast_activity_prepend
  after_update_commit :broadcast_activity_replace

  scope :recent, -> { order(created_at: :desc) }
  scope :timeline, -> { recent.includes(:user).limit(50) }
  scope :by_type, ->(type) { where(action: type) }

  # --- Detail accessors ---

  # Status transition helpers
  def from_status = details["from_status"]
  def to_status = details["to_status"]
  def rationale = details["rationale"]

  # Field update helpers
  def field_name = details["field"]
  def from_field_value = details["from"]
  def to_field_value = details["to"]
  def summary = details["summary"]

  # --- Display configuration ---

  DISPLAY = {
    "created"              => { icon: "M12 4.5v15m7.5-7.5h-15",                                                     accent: "text-green-400" },
    "updated"              => { icon: "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z", accent: "text-blue-400" },
    "destroyed"            => { icon: "M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0", accent: "text-red-400" },
    "field_updated"        => { icon: "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z", accent: "text-amber-400" },
    "status_changed"       => { icon: "M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5", accent: "text-blue-400" },
    "comment_added"        => { icon: "M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z", accent: "text-blue-300" },
    "attachment_added"     => { icon: "M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13", accent: "text-amber-400" },
    "attachment_removed"   => { icon: "M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13", accent: "text-red-400" },
    "assigned"             => { icon: "M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z", accent: "text-green-400" },
    "unassigned"           => { icon: "M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z", accent: "text-gray-400" },
    "relationship_added"   => { icon: "M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m9.364-9.364a4.5 4.5 0 016.364 6.364l-4.5 4.5a4.5 4.5 0 01-7.244-1.242", accent: "text-blue-300" },
    "relationship_removed" => { icon: "M13.181 8.68a4.503 4.503 0 011.903 6.405m-9.768-2.782L3.56 14.06a4.5 4.5 0 006.364 6.364l3.75-3.75m-6-6l6-6m2.121 11.364l1.757-1.757a4.5 4.5 0 000-6.364", accent: "text-red-400" },
    "tag_added"            => { icon: "M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z", accent: "text-green-400" },
    "tag_removed"          => { icon: "M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z", accent: "text-gray-400" }
  }.freeze

  DEFAULT_DISPLAY = { icon: "M12 4.5v15m7.5-7.5h-15", accent: "text-gray-400" }.freeze

  def display_icon
    display_config[:icon]
  end

  def display_accent
    display_config[:accent]
  end

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

  def display_detail
    case action
    when "status_changed"      then rationale&.truncate(120)
    when "field_updated"       then summary || field_change_summary
    when "comment_added"       then subject_label&.truncate(120)
    when "attachment_added", "attachment_removed"
      subject_label&.truncate(80)
    end
  end

  def display_badge
    return unless action == "status_changed"
    to_status&.humanize
  end

  private

  def display_config
    DISPLAY.fetch(action, DEFAULT_DISPLAY)
  end

  def field_change_summary
    from = from_field_value
    to = to_field_value
    return nil unless from.present? || to.present?
    "#{from} -> #{to}"
  end

  def broadcast_activity_prepend
    return unless trackable

    stream = activity_stream_name
    target = activity_target_id

    broadcast_remove_to(stream, target: "no_activity_events")
    broadcast_prepend_to(stream, target: target, partial: broadcast_partial, locals: { event: self })
  end

  def broadcast_activity_replace
    return unless trackable

    stream = activity_stream_name
    broadcast_replace_to(stream, target: dom_id(self), partial: broadcast_partial, locals: { event: self })
  end

  def activity_stream_name
    "#{trackable_type.underscore}_#{trackable_id}_activity"
  end

  def activity_target_id
    "#{trackable_type.underscore}_activity"
  end

  def broadcast_partial
    "activity_events/activity_event"
  end
end
```

## ActivityTrackable Concern

Create `app/models/concerns/activity_trackable.rb`:

```ruby
# frozen_string_literal: true

module ActivityTrackable
  extend ActiveSupport::Concern

  included do
    after_create_commit :log_activity_created
    after_destroy_commit :log_activity_destroyed
  end

  private

  def log_activity_created
    trackable = activity_trackable
    return unless trackable

    ActivityEvent.create!(
      trackable: trackable,
      user: activity_user,
      action: activity_action_created,
      subject: self,
      subject_label: activity_label,
      details: activity_created_details
    )
  end

  def log_activity_destroyed
    trackable = activity_trackable
    return unless trackable

    ActivityEvent.create!(
      trackable: trackable,
      user: activity_user,
      action: activity_action_destroyed,
      subject_type: self.class.name,
      subject_id: id,
      subject_label: activity_label,
      details: activity_destroyed_details
    )
  end

  def activity_created_details = {}
  def activity_destroyed_details = {}
end
```

### Required Interface Methods

Any model including `ActivityTrackable` **must** implement:

| Method | Returns | Purpose |
|--------|---------|---------|
| `activity_trackable` | `ActiveRecord` instance | The parent entity whose timeline gets the event |
| `activity_action_created` | `String` | Action name for creation (e.g., `"comment_added"`) |
| `activity_action_destroyed` | `String` | Action name for destruction (e.g., `"comment_removed"`) |
| `activity_label` | `String` | Human-readable label snapshotted at event creation |
| `activity_user` | `User` or `nil` | Who performed the action |

Optional overrides:

| Method | Default | Purpose |
|--------|---------|---------|
| `activity_created_details` | `{}` | Extra metadata stored in `details` JSONB |
| `activity_destroyed_details` | `{}` | Extra metadata for destroy events |

### Example: Comment model

```ruby
class Comment < ApplicationRecord
  include ActivityTrackable

  belongs_to :post
  belongs_to :user

  def activity_trackable = post
  def activity_action_created = "comment_added"
  def activity_action_destroyed = "comment_removed"
  def activity_label = body.truncate(60)
  def activity_user = user
end
```

### Example: Tagging model (join table)

```ruby
class Tagging < ApplicationRecord
  include ActivityTrackable

  belongs_to :tag
  belongs_to :taggable, polymorphic: true

  def activity_trackable = taggable
  def activity_action_created = "tag_added"
  def activity_action_destroyed = "tag_removed"
  def activity_label = tag.name
  def activity_user = Current.user  # use Current attributes if no direct user association
end
```

### Why `subject_type` and `subject_id` are set manually on destroy

In `log_activity_destroyed`, we set `subject_type` and `subject_id` directly instead of `subject: self` because the record is being destroyed — Active Record may have already nullified or invalidated the association by the time the `after_destroy_commit` callback fires. Setting the polymorphic columns explicitly ensures the reference is preserved in the event record.

## Adding Custom Actions

To add a domain-specific action:

1. Add the action string to the `ACTIONS` array in `ActivityEvent`
2. Add a display entry to the `DISPLAY` hash
3. Create events using the new action string

```ruby
# In ActivityEvent model
ACTIONS = %w[
  created updated destroyed
  field_updated status_changed
  comment_added
  attachment_added attachment_removed
  assigned unassigned
  relationship_added relationship_removed
  tag_added tag_removed
  published           # <-- custom action
  approved            # <-- custom action
].freeze

# In the DISPLAY hash
"published" => { icon: "M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5M6 7.5h3v3H6v-3z", accent: "text-green-400" },
"approved"  => { icon: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z", accent: "text-green-400" },
```
