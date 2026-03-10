# Audit Trail (Optional)

Optional change tracking that layers on top of the basic autosave pattern. This records who changed what, when, with debounced grouping so rapid edits don't flood your audit log.

## The Problem

Without debouncing, the autosave (which fires every ~1 second during active typing) would create a new audit record on every save. A user typing for 5 minutes would generate ~300 audit events -- useless noise.

## The Solution: Server-Side Debounced Audit Events

Use a 5-minute debounce window on the server side. If an audit event for the same field was created within the last 5 minutes, update that event's "to" value instead of creating a new one. This groups related edits into a single "from -> to" event.

### Enhanced Controller

```ruby
class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :edit, :update, :autosave]

  AUTOSAVE_FIELDS = %w[body summary notes].freeze
  AUTOSAVE_DEBOUNCE = 5.minutes

  def autosave
    field = params[:field].to_s
    unless AUTOSAVE_FIELDS.include?(field)
      return render json: { error: "field not allowed" }, status: :bad_request
    end

    old_value = @article.read_attribute(field)
    @article.update_column(field.to_sym, params[:value])
    audit_field_change(field, old_value, params[:value])
    render json: { status: "saved" }
  end

  private

  def audit_field_change(field, old_value, new_value)
    return if old_value == new_value

    # Look for a recent audit event for this same field.
    # If one exists within the debounce window, update it instead
    # of creating a new one. This collapses rapid edits into a
    # single "from (original) -> to (latest)" event.
    recent = @article.activity_events
      .where(action: "field_updated")
      .where("details->>'field' = ?", field)
      .where("created_at > ?", AUTOSAVE_DEBOUNCE.ago)
      .order(created_at: :desc)
      .first

    if recent
      # Update the "to" value to the latest content.
      # The "from" value stays as the original -- this preserves
      # the full before/after diff for the editing session.
      recent.update!(details: recent.details.merge("to" => new_value.to_s.truncate(1500)))
    else
      @article.activity_events.create!(
        user: current_user,
        action: "field_updated",
        details: {
          field: field,
          from: old_value.to_s.truncate(1500),
          to: new_value.to_s.truncate(1500)
        }
      )
    end
  end
end
```

## How the Debounce Works

Timeline example:

```
10:00:00  User starts typing in "body" field
10:00:01  Autosave fires. old="" new="Hello". Creates audit event #1 (from: "", to: "Hello")
10:00:02  Autosave fires. old="Hello" new="Hello world". Updates event #1 (from: "", to: "Hello world")
10:00:03  Autosave fires. old="Hello world" new="Hello world!". Updates event #1 (from: "", to: "Hello world!")
...
10:03:00  User keeps typing. Still within 5-min window. Updates event #1.
10:06:00  User resumes after a break. 5-min window expired. Creates event #2.
```

Result: Instead of hundreds of events, you get 2 events that show meaningful before/after snapshots.

## Choosing the Debounce Window

| Window | Behavior | Good for |
|--------|----------|----------|
| 1 minute | Groups only rapid bursts | Fine-grained audit trails |
| 5 minutes | Groups a typical editing session | Most applications |
| 15 minutes | Groups extended sessions | Low-detail audit needs |
| 30 minutes | Very coarse grouping | Compliance-only logging |

5 minutes is a sensible default. Adjust based on how granular your audit trail needs to be.

## The Activity Event Model

This example uses an `ActivityEvent` model with a JSONB `details` column. If you're using the `rails-activity-timeline` skill, this model already exists. Otherwise, create your own:

### Migration

```ruby
class CreateActivityEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_events do |t|
      t.references :trackable, polymorphic: true, null: false
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.jsonb :details, default: {}
      t.timestamps
    end

    add_index :activity_events, [:trackable_type, :trackable_id, :action]
    add_index :activity_events, :created_at
  end
end
```

### Model

```ruby
class ActivityEvent < ApplicationRecord
  belongs_to :trackable, polymorphic: true
  belongs_to :user, optional: true
end
```

### Association on tracked models

```ruby
class Article < ApplicationRecord
  has_many :activity_events, as: :trackable, dependent: :destroy
end
```

## Using Any Audit Model

The pattern works with any audit/versioning system. The core idea is:

1. Read the old value before saving
2. Save the new value
3. Check for a recent audit record within the debounce window
4. Update the existing record OR create a new one

Adapt the `audit_field_change` method to your audit model's schema. For example, with PaperTrail:

```ruby
def audit_field_change(field, old_value, new_value)
  return if old_value == new_value

  # PaperTrail example -- create a version manually
  recent = @article.versions
    .where("created_at > ?", AUTOSAVE_DEBOUNCE.ago)
    .order(created_at: :desc)
    .first

  if recent && recent.changeset.key?(field)
    # Update existing version's changeset
    changeset = recent.changeset
    changeset[field] = [changeset[field].first, new_value]
    recent.update!(object_changes: changeset.to_yaml)
  else
    # Let PaperTrail create a new version on next save
    # (or create manually if needed)
  end
end
```

## Querying Audit Events

### Recent changes to a field

```ruby
@article.activity_events
  .where(action: "field_updated")
  .where("details->>'field' = ?", "body")
  .order(created_at: :desc)
  .limit(10)
```

### All changes by a user

```ruby
ActivityEvent
  .where(user: current_user)
  .where(action: "field_updated")
  .order(created_at: :desc)
```

### Displaying in a timeline

```erb
<% @article.activity_events.where(action: "field_updated").order(created_at: :desc).each do |event| %>
  <div class="text-sm text-gray-600">
    <strong><%= event.user&.name || "Unknown" %></strong>
    edited <em><%= event.details["field"] %></em>
    <time datetime="<%= event.created_at.iso8601 %>"><%= time_ago_in_words(event.created_at) %> ago</time>
  </div>
<% end %>
```

## Performance Considerations

- The JSONB query (`details->>'field' = ?`) benefits from a GIN index if you have many events:
  ```ruby
  add_index :activity_events, :details, using: :gin
  ```
- `truncate(1500)` prevents storing excessively large text diffs in the JSONB column. Adjust the limit based on your needs.
- The debounce query hits the database on every autosave. For very high-traffic applications, consider caching the recent event ID in Redis or the controller's session.
