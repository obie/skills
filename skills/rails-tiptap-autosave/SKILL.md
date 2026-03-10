---
name: rails-tiptap-autosave
description: Add Tiptap rich text editing with debounced autosave to Rails models using Stimulus. Stores markdown in text columns (not ActionText). Covers installation, Stimulus controller, shared partials, Turbo cache handling, and optional change tracking.
---

# Rails Tiptap Autosave

Add rich text editing with automatic background saving to any Rails model using Tiptap, Stimulus, and markdown stored in plain text columns.

## When to Use This Skill

Invoke this skill when:
1. Adding rich text editing to Rails models without ActionText
2. Implementing inline autosave for text fields
3. Integrating Tiptap editor with Stimulus controllers
4. Building content editing UIs with formatting toolbars
5. Debugging Tiptap + Turbo cache conflicts

## Architecture Overview

**Key decision: Markdown in text columns, NOT ActionText.**

Why this approach:
- No extra tables or polymorphic attachments
- Content is plain text -- easy to query, diff, and version
- Markdown renders cleanly in non-browser contexts (emails, APIs, CLI)
- Simpler mental model than ActionText's rich text blobs

How it works:
1. Tiptap editor (initialized via Stimulus) converts user input to markdown
2. On every keystroke (debounced 1 second), PATCH to autosave endpoint
3. Controller saves markdown to a `text` column via `update_column`
4. Status indicator shows "Saving..." -> "Saved" -> fades

### Key Files

| File | Purpose |
|------|---------|
| `app/javascript/controllers/rich_text_editor_controller.js` | Tiptap Stimulus controller |
| `app/views/shared/_rich_text_field.html.erb` | Reusable editor partial |
| `app/views/shared/_bubble_menu.html.erb` | Formatting toolbar |

## Core Patterns

### 1. Installation & Build Pipeline

npm packages, `@rails/request.js` for CSRF, JS bundler setup (Tiptap does NOT work with importmap), and editor CSS.

See: `references/installation.md`

### 2. Stimulus Controller

The full `rich_text_editor_controller.js` -- handles Tiptap initialization, debounced autosave, BubbleMenu target relocation, Turbo cache cleanup, and bubble menu formatting commands.

See: `references/stimulus-controller.md`

### 3. View Partials

Reusable `_rich_text_field.html.erb` and `_bubble_menu.html.erb` partials with Stimulus data attributes.

See: `references/partials.md`

### 4. Optional Audit Trail

Debounced change tracking that groups rapid edits into single audit events.

See: `references/audit-trail.md`

## Adding Rich Text to a Model

Quick step-by-step for any model (Article, Post, Page, etc.):

### Step 1: Add a text column

```ruby
class AddBodyToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :body, :text
  end
end
```

**Use `text`, NOT `string`.** The `string` type has a 255-character limit -- far too small for rich text content.

### Step 2: Add the autosave route

```ruby
# config/routes.rb
resources :articles do
  member do
    patch :autosave
  end
end
```

### Step 3: Add the autosave controller action

```ruby
class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :edit, :update, :autosave]

  AUTOSAVE_FIELDS = %w[body summary notes].freeze

  def autosave
    field = params[:field].to_s
    unless AUTOSAVE_FIELDS.include?(field)
      return render json: { error: "field not allowed" }, status: :bad_request
    end

    @article.update_column(field.to_sym, params[:value])
    render json: { status: "saved" }
  end
end
```

Key details:
- `update_column` bypasses validations and callbacks -- important for autosave performance
- Field whitelist prevents saving to arbitrary columns (security)
- Returns JSON (not HTML) since this is a background save
- `set_article` must include `:autosave` in the `only:` list

### Step 4: Render the shared partial in your view

```erb
<%= render "shared/rich_text_field",
    url: autosave_article_path(@article),
    field: "body",
    content: @article.body,
    placeholder: "Write your article...",
    label: "Body",
    subtitle: "-- supports markdown formatting" %>
```

## Common Pitfalls

1. **Wrong column type**: Must be `text`, not `string` (255 char limit will silently truncate content)
2. **Missing route**: `patch :autosave` member route must exist or you get 404s on save
3. **Missing before_action**: `set_article` (or equivalent) must include `:autosave` in its `only:` list
4. **Broadcast conflicts**: Never use `broadcasts_refreshes` on models with Tiptap -- Turbo morphing destroys editor state mid-edit. If you need real-time updates, scope broadcasts to exclude the editing user.
5. **ActionText confusion**: This pattern is NOT ActionText. Content is plain markdown in text columns. Do not add `has_rich_text` declarations.
6. **Importmap incompatibility**: Tiptap's packages are not ESM-compatible with importmap. You MUST use esbuild, vite, or another JS bundler. See `references/installation.md` for setup.
7. **BubbleMenu target relocation**: Tiptap's BubbleMenu extension moves the DOM element outside the Stimulus controller scope, making `this.bubbleMenuTarget` unreachable after initialization. The controller must save a reference before calling `new Editor()`. This is the #1 source of "target not found" errors. See `references/stimulus-controller.md`.
8. **Turbo cache stale editors**: Without proper `turbo:before-cache` handling, back-button navigation shows a broken editor that won't reinitialize. The controller must destroy the editor and restore the DOM before Turbo caches the page. See `references/stimulus-controller.md`.

## Multiple Rich Text Fields on One Page

Each field gets its own controller instance via its own `render` call. The `field` value tells the autosave endpoint which column to update:

```erb
<%= render "shared/rich_text_field",
    url: autosave_article_path(@article),
    field: "body",
    content: @article.body,
    placeholder: "Article body...",
    label: "Body" %>

<%= render "shared/rich_text_field",
    url: autosave_article_path(@article),
    field: "summary",
    content: @article.summary,
    placeholder: "Brief summary...",
    label: "Summary" %>
```

Each instance is fully independent -- separate editor, separate autosave, separate status indicator.

## Rendering Saved Markdown

Since content is stored as markdown, you need to render it to HTML for display. Common approaches:

```ruby
# Gemfile
gem "redcarpet"
# or
gem "commonmarker"
```

```ruby
# app/helpers/markdown_helper.rb
module MarkdownHelper
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, filter_html: true)
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true
    )
    markdown.render(text).html_safe
  end
end
```

```erb
<%# In your show view %>
<div class="prose prose-sm max-w-none">
  <%= render_markdown(@article.body) %>
</div>
```
