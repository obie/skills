# AI-Generated Change Summaries

Optional feature: automatically generate human-readable summaries for complex changes using [Raix](https://github.com/OlympiaAI/raix-rails), a Ruby AI framework that provides a clean `ChatCompletion` interface for any LLM provider via OpenRouter.

## When This Is Useful

- **`field_updated` events with long text changes** — a diff between two paragraphs of description text is hard to scan; a one-line summary is much more useful on a timeline
- **Batch field changes** — when multiple fields change at once, a summary like "Updated priority, assignee, and due date" is clearer than three separate events
- **Status transitions with complex rationale** — summarize lengthy rationale text into a concise note

## Architecture

1. Create the `ActivityEvent` with full details (from/to values, etc.)
2. Enqueue a background job to generate the summary
3. The job uses a Raix-powered summarizer to call an LLM
4. The summary is stored in `details["summary"]`
5. The `after_update_commit` callback broadcasts a `replace` to update the event in the live timeline

This keeps event creation fast (no LLM latency in the request cycle) and the timeline updates in place when the summary arrives.

## Setup

### Install Raix

```ruby
# Gemfile
gem "raix-rails"
```

```bash
bundle install
```

### Configure OpenRouter

Raix uses [OpenRouter](https://openrouter.ai/) to access any LLM provider (Claude, GPT, Llama, Mistral, etc.) through a single API.

```ruby
# config/initializers/raix.rb
Raix.configure do |config|
  config.openrouter_client = OpenRouter::Client.new(access_token: ENV.fetch("OPENROUTER_API_KEY"))
end
```

Store your API key in Rails credentials or an environment variable:

```bash
# .env (for development)
OPENROUTER_API_KEY=sk-or-v1-...
```

## Implementation

### Summarizer Service Object

```ruby
# app/services/activity_summary_generator.rb
class ActivitySummaryGenerator
  include Raix::ChatCompletion

  # Use a fast, cheap model — summaries don't need heavy reasoning
  MODEL = ENV.fetch("SUMMARIZER_MODEL", "anthropic/claude-haiku-4-5")

  def initialize(event)
    @event = event
    self.model = MODEL
    self.max_tokens = 150
  end

  def call
    return nil unless summarizable?

    transcript << { role: "system", content: system_prompt }
    transcript << { role: "user", content: user_prompt }

    chat_completion
  end

  private

  attr_reader :event

  def summarizable?
    event.action == "field_updated" &&
      event.from_field_value.present? &&
      event.to_field_value.present? &&
      (event.from_field_value.length > 100 || event.to_field_value.length > 100)
  end

  def system_prompt
    "You summarize content changes in one concise sentence under 100 characters. " \
    "Focus on what meaningfully changed, not formatting differences. " \
    "Return only the summary sentence, nothing else."
  end

  def user_prompt
    <<~PROMPT
      Summarize the change to the "#{event.field_name}" field:

      Previous value:
      #{event.from_field_value.truncate(1000)}

      New value:
      #{event.to_field_value.truncate(1000)}
    PROMPT
  end
end
```

**Why Raix?**
- `include Raix::ChatCompletion` gives you `transcript`, `chat_completion`, `model=`, and `max_tokens=` — everything needed for a single-turn LLM call in a clean Ruby object
- Model is configurable via env var — switch between Claude Haiku, GPT-4o-mini, or any OpenRouter model without code changes
- The `chat_completion` method returns the response text directly — no parsing boilerplate
- Works with OpenRouter's unified API, so you're not locked into any single provider

### Background Job

```ruby
# app/jobs/generate_activity_summary_job.rb
class GenerateActivitySummaryJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(activity_event_id)
    event = ActivityEvent.find_by(id: activity_event_id)
    return unless event
    return if event.details["summary"].present?

    summary = ActivitySummaryGenerator.new(event).call
    return unless summary

    event.update!(details: event.details.merge("summary" => summary))
    # The after_update_commit callback broadcasts the updated event
  end
end
```

### Triggering the Job

Enqueue the job after creating a `field_updated` event:

```ruby
# In your controller or service
event = ActivityEvent.create!(
  trackable: @project,
  user: current_user,
  action: "field_updated",
  details: {
    field: "description",
    from: @project.description_previously_was.to_s.truncate(1500),
    to: @project.description.to_s.truncate(1500)
  }
)

GenerateActivitySummaryJob.perform_later(event.id) if event.from_field_value.to_s.length > 100
```

Or make it automatic with an `after_create_commit` callback on `ActivityEvent`:

```ruby
# In ActivityEvent model
after_create_commit :enqueue_summary_generation, if: :needs_summary?

private

def needs_summary?
  action == "field_updated" &&
    (from_field_value.to_s.length > 100 || to_field_value.to_s.length > 100)
end

def enqueue_summary_generation
  GenerateActivitySummaryJob.perform_later(id)
end
```

## How the Summary Appears in the Timeline

The `display_detail` method checks for `summary` first:

```ruby
def display_detail
  case action
  when "field_updated" then summary || field_change_summary
  # ...
  end
end
```

When the job completes and updates `details["summary"]`, the `after_update_commit` callback broadcasts a `replace`, and the event partial re-renders with the summary text. Users see the timeline event update in place without a page reload.

## Advanced: Multi-Turn or Structured Summaries

Raix supports multi-turn conversations and function calling. For more sophisticated summaries:

```ruby
class DetailedSummaryGenerator
  include Raix::ChatCompletion

  def initialize(event)
    @event = event
    self.model = "anthropic/claude-sonnet-4-20250514"
  end

  def call
    transcript << { role: "system", content: "You analyze content changes and provide structured summaries." }
    transcript << { role: "user", content: "What changed?" }
    transcript << { role: "assistant", content: "I'll analyze the change. Please provide the before and after content." }
    transcript << { role: "user", content: diff_prompt }

    chat_completion
  end

  private

  def diff_prompt
    "Before:\n#{@event.from_field_value.truncate(1500)}\n\nAfter:\n#{@event.to_field_value.truncate(1500)}"
  end
end
```

## Cost and Rate Limiting Considerations

- Only summarize changes above a minimum length threshold (> 100 characters)
- Use a small, fast model (`claude-haiku-4-5` or `gpt-4o-mini`) — summaries don't need heavy reasoning
- Set `max_tokens` low (100-150) since summaries should be one sentence
- Use `retry_on` with polynomial backoff to handle rate limits gracefully
- The model is configurable via `SUMMARIZER_MODEL` env var — easy to swap in development vs production
- OpenRouter provides unified rate limiting and cost tracking across all providers

## Testing

```ruby
# test/services/activity_summary_generator_test.rb
class ActivitySummaryGeneratorTest < ActiveSupport::TestCase
  test "returns nil for short field changes" do
    event = ActivityEvent.new(
      action: "field_updated",
      details: { "field" => "title", "from" => "Old", "to" => "New" }
    )
    assert_nil ActivitySummaryGenerator.new(event).call
  end

  test "returns nil for non-field_updated events" do
    event = ActivityEvent.new(action: "created")
    assert_nil ActivitySummaryGenerator.new(event).call
  end

  # Stub the Raix chat_completion for unit tests
  test "generates summary for long text changes" do
    event = ActivityEvent.new(
      action: "field_updated",
      details: {
        "field" => "description",
        "from" => "A" * 200,
        "to" => "B" * 200
      }
    )

    generator = ActivitySummaryGenerator.new(event)
    generator.stub(:chat_completion, "Replaced entire description content") do
      assert_equal "Replaced entire description content", generator.call
    end
  end
end
```
