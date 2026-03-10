# Stimulus Controller

The `rich_text_editor_controller.js` is the core of the integration. It initializes Tiptap, manages autosave, handles Turbo cache cleanup, and wires up the bubble menu.

## Full Controller

```javascript
// app/javascript/controllers/rich_text_editor_controller.js
import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

// Inline debounce -- no external dependency needed.
// Returns a function that delays invoking `fn` until `ms` milliseconds
// have elapsed since the last invocation.
function debounce(fn, ms) {
  let timer
  return (...args) => {
    clearTimeout(timer)
    timer = setTimeout(() => fn(...args), ms)
  }
}

export default class extends Controller {
  static targets = ["editor", "bubbleMenu", "status"]
  static values = {
    url: String,       // Autosave endpoint (e.g. "/articles/123/autosave")
    content: String,   // Initial markdown content from the server
    field: String,     // Column name to save to (e.g. "body")
    placeholder: { type: String, default: "Start writing..." }
  }

  async connect() {
    this.unsavedChanges = false
    this.isConnected = true
    this.debouncedSave = debounce(() => this.save(), 1000)

    // ---------------------------------------------------------------
    // CRITICAL: Save bubble menu reference BEFORE Tiptap initialization.
    //
    // The BubbleMenu extension repositions the DOM element outside the
    // Stimulus controller's scope (it appends it to document.body or a
    // tippy container). After this happens, `this.bubbleMenuTarget` throws
    // "Missing target element" because Stimulus can no longer find it
    // within the controller's DOM tree.
    //
    // We save both the element reference (for passing to BubbleMenu.configure)
    // and its outerHTML (for restoring it into the DOM before Turbo caches).
    // ---------------------------------------------------------------
    this._bubbleMenuEl = this.hasBubbleMenuTarget ? this.bubbleMenuTarget : null
    this._bubbleMenuHtml = this._bubbleMenuEl ? this._bubbleMenuEl.outerHTML : null

    // ---------------------------------------------------------------
    // Turbo event handlers
    // ---------------------------------------------------------------

    // Flush pending changes before Turbo navigates away.
    // Without this, clicking a link while typing loses the last edit.
    this.beforeVisitHandler = () => {
      if (this.unsavedChanges) this.save()
    }

    // Destroy editor and restore DOM for Turbo's snapshot cache.
    //
    // Why this matters:
    // 1. Turbo caches the current page DOM before navigating away.
    // 2. On back-button navigation, Turbo restores this cached DOM.
    // 3. If the cache contains a live Tiptap instance, the ProseMirror
    //    contenteditable div is stale -- Stimulus calls connect() again
    //    but the editor target already has orphaned ProseMirror nodes.
    // 4. By destroying the editor and clearing the target's innerHTML
    //    before caching, we ensure a clean slate for re-initialization.
    //
    // The BubbleMenu element also needs restoration: the BubbleMenu
    // extension removes it from the DOM on editor.destroy(). If we
    // don't re-insert it, the cached page won't have the target element
    // and the next connect() will fail to find it.
    this.beforeCacheHandler = () => {
      if (this.editor) {
        this.editor.destroy()
        this.editor = null
      }
      if (this._bubbleMenuHtml && !this.hasBubbleMenuTarget) {
        this.editorTarget.insertAdjacentHTML("beforebegin", this._bubbleMenuHtml)
      }
      this.editorTarget.innerHTML = ""
    }

    document.addEventListener("turbo:before-visit", this.beforeVisitHandler)
    document.addEventListener("turbo:before-cache", this.beforeCacheHandler)
    await this.initEditor()
  }

  disconnect() {
    this.isConnected = false
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler)
    document.removeEventListener("turbo:before-cache", this.beforeCacheHandler)

    // Flush any pending changes before teardown
    if (this.editor && this.unsavedChanges) {
      this.save()
    }
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  async initEditor() {
    // Clear any stale DOM from a Turbo cache restoration
    this.editorTarget.innerHTML = ""

    // ---------------------------------------------------------------
    // Dynamic imports keep Tiptap out of the initial JS bundle.
    // This is especially valuable if only some pages use the editor.
    //
    // Alternative: if you created a barrel file (see installation.md),
    // replace these individual imports with:
    //   const { Editor, StarterKit, BubbleMenu, Link, Placeholder, Markdown }
    //     = await import("lib/tiptap-bundle")
    // ---------------------------------------------------------------
    const { Editor } = await import("@tiptap/core")
    const StarterKit = (await import("@tiptap/starter-kit")).default
    const BubbleMenu = (await import("@tiptap/extension-bubble-menu")).default
    const Link = (await import("@tiptap/extension-link")).default
    const Placeholder = (await import("@tiptap/extension-placeholder")).default
    const { Markdown } = await import("tiptap-markdown")

    // ---------------------------------------------------------------
    // Guard: controller may have disconnected during the async imports.
    //
    // Scenario: user navigates away quickly. The dynamic import() calls
    // are in-flight, and by the time they resolve, disconnect() has
    // already been called. Without this guard, we'd initialize an editor
    // on a detached DOM node, causing memory leaks and errors.
    // ---------------------------------------------------------------
    if (!this.isConnected) return

    // Use the saved reference -- after Turbo cache restore, the Stimulus
    // target may not resolve because BubbleMenu was moved outside scope.
    const bubbleMenuEl = this.hasBubbleMenuTarget ? this.bubbleMenuTarget : this._bubbleMenuEl

    const extensions = [
      StarterKit.configure({
        heading: { levels: [1, 2, 3] }
      }),
      Link.configure({
        openOnClick: false
      }),
      Placeholder.configure({
        placeholder: this.placeholderValue
      }),
      Markdown.configure({
        html: false,                // Don't allow HTML in markdown output
        transformCopiedText: true,  // Copy as markdown
        transformPastedText: true   // Paste markdown as rich text
      })
    ]

    if (bubbleMenuEl) {
      extensions.push(BubbleMenu.configure({ element: bubbleMenuEl }))
    }

    this.editor = new Editor({
      element: this.editorTarget,
      extensions,
      content: this.contentValue || "",
      editorProps: {
        attributes: {
          // Tailwind prose classes for nice default typography.
          // Adjust these classes to match your design system.
          class: "prose prose-sm max-w-none focus:outline-none min-h-[120px] cursor-text"
        }
      },
      onUpdate: () => {
        this.unsavedChanges = true
        this.debouncedSave()
      },
      onSelectionUpdate: ({ editor }) => {
        this.updateButtonStates(editor)
      }
    })
  }

  // ---------------------------------------------------------------
  // contentValueChanged: Stimulus callback for external content updates.
  //
  // This fires when the `data-rich-text-editor-content-value` attribute
  // changes -- typically from a Turbo morph or Turbo Stream update.
  //
  // Why we skip when unsavedChanges is true:
  // If the user is actively typing, a Turbo morph might arrive with
  // stale content (the server's version before the latest autosave).
  // Overwriting the editor would destroy the user's in-progress edits.
  // We only sync external updates when the editor is "idle".
  // ---------------------------------------------------------------
  contentValueChanged() {
    if (!this.editor) return
    if (this.unsavedChanges) return

    const currentMarkdown = this.editor.storage.markdown.getMarkdown()
    if (currentMarkdown !== this.contentValue) {
      this.editor.commands.setContent(this.contentValue || "")
    }
  }

  // ---------------------------------------------------------------
  // Bubble menu button state management
  // ---------------------------------------------------------------

  updateButtonStates(editor) {
    const menuEl = this.hasBubbleMenuTarget ? this.bubbleMenuTarget : this._bubbleMenuEl
    if (!menuEl) return
    menuEl.querySelectorAll("[data-format]").forEach(btn => {
      const active = this.isFormatActive(editor, btn.dataset.format)
      btn.classList.toggle("is-active", active)
    })
  }

  isFormatActive(editor, format) {
    switch (format) {
      case "bold": return editor.isActive("bold")
      case "italic": return editor.isActive("italic")
      case "strike": return editor.isActive("strike")
      case "code": return editor.isActive("code")
      case "h1": return editor.isActive("heading", { level: 1 })
      case "h2": return editor.isActive("heading", { level: 2 })
      case "h3": return editor.isActive("heading", { level: 3 })
      case "bulletList": return editor.isActive("bulletList")
      case "orderedList": return editor.isActive("orderedList")
      case "blockquote": return editor.isActive("blockquote")
      case "codeBlock": return editor.isActive("codeBlock")
      default: return false
    }
  }

  // ---------------------------------------------------------------
  // Autosave
  //
  // Uses @rails/request.js `patch()` which automatically:
  // - Reads the CSRF token from <meta name="csrf-token">
  // - Sets the X-CSRF-Token header
  // - Sets Accept and Content-Type headers
  //
  // The server-side action should use `update_column` (not `update`)
  // to bypass validations and callbacks. This is intentional:
  // - Autosave fires every ~1 second during active typing
  // - Running full validations on every keystroke is wasteful
  // - Callbacks (like broadcasting) would cause Turbo conflicts
  // - The field whitelist on the server provides the safety net
  // ---------------------------------------------------------------

  async save() {
    if (!this.editor) return

    const markdown = this.editor.storage.markdown.getMarkdown()
    this.showStatus("Saving...")

    try {
      const response = await patch(this.urlValue, {
        body: JSON.stringify({ field: this.fieldValue, value: markdown }),
        contentType: "application/json",
        responseKind: "json"
      })

      if (response.ok) {
        this.unsavedChanges = false
        this.showStatus("Saved")
        this.hideStatusAfterDelay()
      } else {
        this.showStatus("Save failed")
      }
    } catch {
      this.showStatus("Save failed")
    }
  }

  // ---------------------------------------------------------------
  // Status indicator
  // ---------------------------------------------------------------

  showStatus(text) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.classList.remove("opacity-0")
  }

  hideStatusAfterDelay() {
    clearTimeout(this.hideTimeout)
    this.hideTimeout = setTimeout(() => {
      if (this.hasStatusTarget) {
        this.statusTarget.classList.add("opacity-0")
      }
    }, 2000)
  }

  // ---------------------------------------------------------------
  // Bubble menu formatting commands
  //
  // Each method maps to a button in the bubble menu partial.
  // The chain().focus().toggle*().run() pattern:
  // 1. chain() - starts a command chain
  // 2. focus() - returns focus to the editor (bubble menu click steals it)
  // 3. toggle*() - applies/removes the formatting
  // 4. run() - executes the chain
  // ---------------------------------------------------------------

  toggleBold() { this.editor?.chain().focus().toggleBold().run() }
  toggleItalic() { this.editor?.chain().focus().toggleItalic().run() }
  toggleStrike() { this.editor?.chain().focus().toggleStrike().run() }
  toggleCode() { this.editor?.chain().focus().toggleCode().run() }
  toggleCodeBlock() { this.editor?.chain().focus().toggleCodeBlock().run() }
  toggleBulletList() { this.editor?.chain().focus().toggleBulletList().run() }
  toggleOrderedList() { this.editor?.chain().focus().toggleOrderedList().run() }
  toggleBlockquote() { this.editor?.chain().focus().toggleBlockquote().run() }

  toggleHeading(event) {
    const level = parseInt(event.params.level)
    this.editor?.chain().focus().toggleHeading({ level }).run()
  }
}
```

## Key Design Decisions Explained

### Why save the BubbleMenu reference early?

The BubbleMenu extension uses Tippy.js under the hood. During initialization, it removes the menu element from its original DOM position and appends it to a Tippy container (usually `document.body`). After this, Stimulus can no longer find the element via `this.bubbleMenuTarget` because it is outside the controller's scope.

By saving `this._bubbleMenuEl` before `new Editor()`, we retain a direct reference to the element regardless of where Tippy moves it.

We also save `this._bubbleMenuHtml` (the serialized HTML) so we can re-insert the element into the DOM before Turbo caches the page. Without this, the Turbo snapshot would be missing the bubble menu element entirely, and the next `connect()` call (on back-button navigation) would fail.

### Why the `isConnected` guard after async imports?

The `await import()` calls are asynchronous. During the time they take to resolve (potentially hundreds of milliseconds on slow connections), the user might navigate away. If that happens:

1. `disconnect()` fires, setting `this.isConnected = false`
2. The `import()` promises resolve
3. `initEditor()` continues executing with stale references

Without the guard, we would create a Tiptap editor on a detached DOM node, leaking memory and potentially throwing errors.

### Why `contentValueChanged` skips when `unsavedChanges` is true?

Consider this race condition:
1. User types "Hello world" -- autosave fires with "Hello world"
2. Server saves "Hello world" and broadcasts a Turbo morph
3. User has already typed "Hello world, how are you?" locally
4. Turbo morph updates the content attribute to "Hello world" (server's version)
5. `contentValueChanged` fires with the stale "Hello world"

If we applied this update, the user's " how are you?" would vanish. The `unsavedChanges` flag prevents this -- we only sync external updates when the user isn't actively editing.

### Why `update_column` on the server side?

`update_column` writes directly to the database, bypassing:
- **Validations**: Autosave fires on every debounced keystroke. Running `validates :body, length: { minimum: 100 }` on a half-written paragraph would fail and show confusing errors.
- **Callbacks**: `after_save` callbacks (like broadcasting, sending notifications, updating timestamps) should not fire on every autosave keystroke.
- **`updated_at` touch**: `update_column` does NOT update `updated_at`, which is usually what you want for background saves.

The field whitelist (`AUTOSAVE_FIELDS`) provides security -- it's a controlled list of columns that can be written to.

## Adding Table Support

If you need table editing, add the table extensions:

```bash
yarn add @tiptap/extension-table @tiptap/extension-table-row \
  @tiptap/extension-table-header @tiptap/extension-table-cell
```

Then add them to the extensions array in `initEditor()`:

```javascript
const Table = (await import("@tiptap/extension-table")).default
const TableRow = (await import("@tiptap/extension-table-row")).default
const TableHeader = (await import("@tiptap/extension-table-header")).default
const TableCell = (await import("@tiptap/extension-table-cell")).default

const extensions = [
  // ... existing extensions ...
  Table.configure({ resizable: false }),
  TableRow,
  TableHeader,
  TableCell,
]
```

## Customizing the Editor

### Change the debounce delay

The default 1-second debounce is a good balance between responsiveness and server load. To adjust:

```javascript
// More responsive (more server requests)
this.debouncedSave = debounce(() => this.save(), 500)

// Less server load (user waits longer to see "Saved")
this.debouncedSave = debounce(() => this.save(), 2000)
```

### Change editor prose classes

Modify the `class` attribute in `editorProps`:

```javascript
editorProps: {
  attributes: {
    class: "prose prose-lg max-w-none dark:prose-invert focus:outline-none min-h-[200px]"
  }
}
```

### Add custom keyboard shortcuts

```javascript
import { Extension } from "@tiptap/core"

const CustomKeymap = Extension.create({
  addKeyboardShortcuts() {
    return {
      "Mod-Shift-s": () => {
        // Force save (bypass debounce)
        this.options.onForceSave?.()
        return true
      }
    }
  }
})

// In initEditor():
extensions.push(CustomKeymap.configure({
  onForceSave: () => this.save()
}))
```
