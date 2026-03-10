# Installation & Build Pipeline

## npm Packages

Install Tiptap core and extensions:

```bash
yarn add @tiptap/core @tiptap/starter-kit @tiptap/extension-bubble-menu \
  @tiptap/extension-link @tiptap/extension-placeholder \
  @tiptap/extension-table @tiptap/extension-table-row \
  @tiptap/extension-table-header @tiptap/extension-table-cell \
  tiptap-markdown
```

### @rails/request.js

```bash
yarn add @rails/request.js
```

This library handles CSRF token injection automatically. When you call `patch()`, `post()`, or `put()`, it reads the CSRF meta tag from the page and includes it in the request headers. Without this, your autosave PATCH requests will fail with 422 Unprocessable Entity.

## Build Pipeline

**Tiptap does NOT work with importmap.**

Tiptap's packages use CommonJS and have deep dependency trees that importmap cannot resolve. You must use a JavaScript bundler:

- **`jsbundling-rails` with esbuild** (recommended for simplicity)
- **Vite via `vite_rails`** (if you prefer Vite's dev experience)
- **Webpack via `shakapacker`** (if already using Webpack)

### Setting up jsbundling-rails (if you don't already have a bundler)

```bash
bundle add jsbundling-rails
rails javascript:install:esbuild
```

This creates:
- `app/javascript/application.js` -- your entry point
- `package.json` with an esbuild build script
- `Procfile.dev` entries for the build watcher

After installation, ensure your layout uses `javascript_include_tag` (not `javascript_importmap_tags`):

```erb
<%# app/views/layouts/application.html.erb %>
<%= javascript_include_tag "application", "data-turbo-track": "reload", type: "module" %>
```

### Verifying your setup

After installing packages, verify everything builds:

```bash
yarn build
```

If you see errors about missing modules, check that all `@tiptap/*` packages are in `package.json`.

## CSS Setup

Tiptap renders content inside a `.ProseMirror` element. You need minimal CSS for the editor and bubble menu.

### Tailwind CSS version

```css
/* app/assets/stylesheets/tiptap.css (or in your main stylesheet) */

/* Editor area */
.ProseMirror {
  outline: none;
  min-height: 120px;
}

/* Placeholder text for empty editor */
.ProseMirror p.is-editor-empty:first-child::before {
  content: attr(data-placeholder);
  float: left;
  color: theme('colors.gray.400');
  pointer-events: none;
  height: 0;
}

/* Bubble menu container */
.bubble-menu {
  display: flex;
  align-items: center;
  gap: 2px;
  padding: 4px;
  background: white;
  border: 1px solid theme('colors.gray.200');
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
}

.bubble-menu button {
  padding: 4px 6px;
  border-radius: 4px;
  font-size: 12px;
  color: theme('colors.gray.600');
  cursor: pointer;
}

.bubble-menu button:hover,
.bubble-menu button.is-active {
  background: theme('colors.gray.100');
  color: theme('colors.gray.900');
}

.bubble-divider {
  width: 1px;
  height: 16px;
  background: theme('colors.gray.200');
  margin: 0 4px;
}
```

### Dark mode variants (Tailwind)

```css
/* Dark mode support */
@media (prefers-color-scheme: dark) {
  .ProseMirror p.is-editor-empty:first-child::before {
    color: theme('colors.gray.500');
  }

  .bubble-menu {
    background: theme('colors.gray.800');
    border-color: theme('colors.gray.700');
    box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.3);
  }

  .bubble-menu button {
    color: theme('colors.gray.300');
  }

  .bubble-menu button:hover,
  .bubble-menu button.is-active {
    background: theme('colors.gray.700');
    color: theme('colors.gray.100');
  }

  .bubble-divider {
    background: theme('colors.gray.600');
  }
}
```

If you use Tailwind's `dark:` class strategy instead of `prefers-color-scheme`, adjust accordingly:

```css
.dark .bubble-menu {
  background: theme('colors.gray.800');
  border-color: theme('colors.gray.700');
}
/* ... etc */
```

### Plain CSS version (no Tailwind)

```css
.ProseMirror {
  outline: none;
  min-height: 120px;
}

.ProseMirror p.is-editor-empty:first-child::before {
  content: attr(data-placeholder);
  float: left;
  color: #9ca3af;
  pointer-events: none;
  height: 0;
}

.bubble-menu {
  display: flex;
  align-items: center;
  gap: 2px;
  padding: 4px;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.bubble-menu button {
  padding: 4px 6px;
  border: none;
  border-radius: 4px;
  font-size: 12px;
  color: #4b5563;
  background: transparent;
  cursor: pointer;
}

.bubble-menu button:hover,
.bubble-menu button.is-active {
  background: #f3f4f6;
  color: #111827;
}

.bubble-divider {
  width: 1px;
  height: 16px;
  background: #e5e7eb;
  margin: 0 4px;
}
```

## Optional: Barrel File for Cleaner Imports

If you use Tiptap across multiple controllers or files, create a barrel file to centralize imports:

```javascript
// app/javascript/lib/tiptap-bundle.js
export { Editor } from "@tiptap/core"
export { default as StarterKit } from "@tiptap/starter-kit"
export { default as BubbleMenu } from "@tiptap/extension-bubble-menu"
export { default as Link } from "@tiptap/extension-link"
export { default as Placeholder } from "@tiptap/extension-placeholder"
export { default as Table } from "@tiptap/extension-table"
export { default as TableRow } from "@tiptap/extension-table-row"
export { default as TableHeader } from "@tiptap/extension-table-header"
export { default as TableCell } from "@tiptap/extension-table-cell"
export { Markdown } from "tiptap-markdown"
```

Then in your controller:

```javascript
const { Editor, StarterKit, BubbleMenu, Link, Placeholder, Markdown } =
  await import("lib/tiptap-bundle")
```

This keeps import paths short and gives you a single place to manage Tiptap versions. The barrel file also makes it easy to swap extensions in or out without touching every controller that uses Tiptap.

## Verify Installation Checklist

After setup, confirm:

- [ ] `yarn build` succeeds without errors
- [ ] Stimulus controller file is registered (auto-loaded by `esbuild` + `stimulus-loading`)
- [ ] `@rails/request.js` is importable
- [ ] CSS file is included in your layout (either via asset pipeline or bundler)
- [ ] A `<meta name="csrf-token">` tag exists in your layout (required by `@rails/request.js`)
