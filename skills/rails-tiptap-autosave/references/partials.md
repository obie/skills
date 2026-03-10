# View Partials

Two shared partials make it easy to drop rich text editing into any view. Place these in `app/views/shared/`.

## Rich Text Field Partial

```erb
<%# app/views/shared/_rich_text_field.html.erb %>
<%# locals: (url:, field:, content:, placeholder:, label:, subtitle: nil) %>
<div data-controller="rich-text-editor"
     data-rich-text-editor-url-value="<%= url %>"
     data-rich-text-editor-field-value="<%= field %>"
     data-rich-text-editor-content-value="<%= content.to_s %>"
     data-rich-text-editor-placeholder-value="<%= placeholder %>">
  <div class="flex items-center justify-between mb-3">
    <div class="flex items-baseline gap-2">
      <span class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider"><%= label %></span>
      <% if subtitle %>
        <span class="text-[10px] text-gray-400 dark:text-gray-500"><%= subtitle %></span>
      <% end %>
    </div>
    <span data-rich-text-editor-target="status"
          class="text-[10px] font-medium text-gray-400 uppercase tracking-wider transition-opacity duration-300 opacity-0"></span>
  </div>
  <%= render "shared/bubble_menu" %>
  <div data-rich-text-editor-target="editor"></div>
</div>
```

### How it works

- The outer `<div>` is the Stimulus controller scope. All `data-rich-text-editor-*` attributes bind to the controller's values and targets.
- `url` is the autosave endpoint (e.g. `autosave_article_path(@article)`).
- `field` tells the server which column to update (e.g. `"body"`).
- `content` is the initial markdown from the database. `.to_s` handles nil gracefully.
- The `status` span shows "Saving..." / "Saved" / "Save failed" and fades via `opacity-0`.
- The `<%# locals: ... %>` comment documents the expected arguments (Ruby 3.2+ strict locals syntax). For older Ruby versions, use `local_assigns[:subtitle]` instead of checking `subtitle` directly.

### For older Ruby versions (before strict locals)

If your Ruby version doesn't support the `locals:` comment directive, the partial still works -- just be aware that `subtitle` will be `nil` if not passed, and the `<% if subtitle %>` check handles that correctly.

## Bubble Menu Partial

```erb
<%# app/views/shared/_bubble_menu.html.erb %>
<div data-rich-text-editor-target="bubbleMenu" class="bubble-menu">
  <button type="button" data-format="bold" data-action="click->rich-text-editor#toggleBold" title="Bold"><strong>B</strong></button>
  <button type="button" data-format="italic" data-action="click->rich-text-editor#toggleItalic" title="Italic"><em>I</em></button>
  <button type="button" data-format="strike" data-action="click->rich-text-editor#toggleStrike" title="Strikethrough" class="line-through">S</button>
  <button type="button" data-format="code" data-action="click->rich-text-editor#toggleCode" title="Inline Code" class="font-mono text-[10px]">&lt;&gt;</button>
  <span class="bubble-divider"></span>
  <button type="button" data-format="h1" data-action="click->rich-text-editor#toggleHeading" data-rich-text-editor-level-param="1" title="Heading 1" class="text-[10px] font-bold">H1</button>
  <button type="button" data-format="h2" data-action="click->rich-text-editor#toggleHeading" data-rich-text-editor-level-param="2" title="Heading 2" class="text-[10px] font-bold">H2</button>
  <button type="button" data-format="h3" data-action="click->rich-text-editor#toggleHeading" data-rich-text-editor-level-param="3" title="Heading 3" class="text-[10px] font-bold">H3</button>
  <span class="bubble-divider"></span>
  <button type="button" data-format="bulletList" data-action="click->rich-text-editor#toggleBulletList" title="Bullet List">
    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 6.75h7.5M8.25 12h7.5m-7.5 5.25h7.5M3.75 6.75h.007v.008H3.75V6.75zm0 5.25h.007v.008H3.75V12zm0 5.25h.007v.008H3.75v-.008z"/></svg>
  </button>
  <button type="button" data-format="orderedList" data-action="click->rich-text-editor#toggleOrderedList" title="Numbered List">
    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M8.242 5.992h12m-12 6.003h12m-12 5.999h12M4.117 7.495v-3.75H2.99m1.125 3.75H2.99m1.125 0H5.24m-1.92 2.577a1.125 1.125 0 111.591 1.59l-1.83 1.83h2.16"/></svg>
  </button>
  <button type="button" data-format="blockquote" data-action="click->rich-text-editor#toggleBlockquote" title="Blockquote">
    <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24"><path d="M4.583 17.321C3.553 16.227 3 15 3 13.011c0-3.5 2.457-6.637 6.03-8.188l.893 1.378c-3.335 1.804-3.987 4.145-4.247 5.621.537-.278 1.24-.375 1.929-.311 1.804.167 3.226 1.648 3.226 3.489a3.5 3.5 0 01-3.5 3.5c-1.073 0-2.099-.49-2.748-1.179zm10 0C13.553 16.227 13 15 13 13.011c0-3.5 2.457-6.637 6.03-8.188l.893 1.378c-3.335 1.804-3.987 4.145-4.247 5.621.537-.278 1.24-.375 1.929-.311 1.804.167 3.226 1.648 3.226 3.489a3.5 3.5 0 01-3.5 3.5c-1.073 0-2.099-.49-2.748-1.179z"/></svg>
  </button>
  <button type="button" data-format="codeBlock" data-action="click->rich-text-editor#toggleCodeBlock" title="Code Block" class="font-mono text-[10px]">{}</button>
</div>
```

### How it works

- The `data-rich-text-editor-target="bubbleMenu"` connects this element to the Stimulus controller.
- Each button uses `data-action` to call the corresponding toggle method on the controller.
- The `data-format` attribute is used by `updateButtonStates()` to toggle the `is-active` CSS class when the cursor is on formatted text.
- Heading buttons use `data-rich-text-editor-level-param` to pass the heading level (1, 2, or 3) to the `toggleHeading` action.
- SVG icons are inline to avoid external dependencies. Replace them with your icon system if you have one.

### Important: BubbleMenu DOM relocation

After Tiptap initializes, the BubbleMenu extension **moves this entire `<div>` out of the controller's DOM tree** into a Tippy.js popup container. This is why the Stimulus controller saves a reference to it before initialization. Do not rely on `this.bubbleMenuTarget` after the editor is created -- use `this._bubbleMenuEl` instead.

## Usage Examples

### Basic usage

```erb
<%= render "shared/rich_text_field",
    url: autosave_article_path(@article),
    field: "body",
    content: @article.body,
    placeholder: "Write your article...",
    label: "Body",
    subtitle: "-- supports markdown formatting" %>
```

### Without subtitle

```erb
<%= render "shared/rich_text_field",
    url: autosave_post_path(@post),
    field: "content",
    content: @post.content,
    placeholder: "What's on your mind?",
    label: "Content" %>
```

### Multiple editors on one page

```erb
<%= render "shared/rich_text_field",
    url: autosave_page_path(@page),
    field: "body",
    content: @page.body,
    placeholder: "Page content...",
    label: "Body" %>

<div class="mt-8">
  <%= render "shared/rich_text_field",
      url: autosave_page_path(@page),
      field: "sidebar",
      content: @page.sidebar,
      placeholder: "Sidebar content...",
      label: "Sidebar" %>
</div>
```

Each `render` call creates an independent Stimulus controller instance with its own editor, autosave, and status indicator.

### Inside a form (hybrid approach)

If you want both autosave AND a traditional form submit, you can include the editor alongside regular form fields. The autosave runs independently -- the form submit handles other fields:

```erb
<%= form_with model: @article do |f| %>
  <%= f.text_field :title, class: "..." %>

  <%# This autosaves independently of the form %>
  <%= render "shared/rich_text_field",
      url: autosave_article_path(@article),
      field: "body",
      content: @article.body,
      placeholder: "Write your article...",
      label: "Body" %>

  <%= f.submit "Save Title" %>
<% end %>
```

## Customizing the Partials

### Without Tailwind CSS

If you're not using Tailwind, replace the utility classes with your own CSS:

```erb
<%# app/views/shared/_rich_text_field.html.erb %>
<div data-controller="rich-text-editor"
     data-rich-text-editor-url-value="<%= url %>"
     data-rich-text-editor-field-value="<%= field %>"
     data-rich-text-editor-content-value="<%= content.to_s %>"
     data-rich-text-editor-placeholder-value="<%= placeholder %>">
  <div class="rich-text-header">
    <span class="rich-text-label"><%= label %></span>
    <% if subtitle %>
      <span class="rich-text-subtitle"><%= subtitle %></span>
    <% end %>
    <span data-rich-text-editor-target="status" class="rich-text-status"></span>
  </div>
  <%= render "shared/bubble_menu" %>
  <div data-rich-text-editor-target="editor"></div>
</div>
```

Then style `.rich-text-header`, `.rich-text-label`, `.rich-text-subtitle`, and `.rich-text-status` in your CSS.

### Adding a character count

Add a target to the controller and update it in the `onUpdate` callback:

```erb
<span data-rich-text-editor-target="charCount" class="text-xs text-gray-400"></span>
```

```javascript
// In the controller, add to static targets:
static targets = ["editor", "bubbleMenu", "status", "charCount"]

// In onUpdate:
onUpdate: () => {
  this.unsavedChanges = true
  this.debouncedSave()
  if (this.hasCharCountTarget) {
    const text = this.editor.storage.markdown.getMarkdown()
    this.charCountTarget.textContent = `${text.length} characters`
  }
}
```

### Adding a word count

Similar approach:

```javascript
if (this.hasWordCountTarget) {
  const text = this.editor.getText()
  const words = text.trim().split(/\s+/).filter(w => w.length > 0).length
  this.wordCountTarget.textContent = `${words} words`
}
```
