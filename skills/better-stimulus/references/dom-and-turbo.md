# DOM Manipulation and Turbo Integration

## Use `<template>` to Restore DOM State

### Purpose

Reset your DOM to a known state when:
- External libraries remove or manipulate your HTML
- Preparing for Turbo's caching mechanism
- Need to restore original markup after interactions

### Problem Statement

Two main pain points:

1. **External libraries** (SemanticUI, Bootstrap) yank away HTML after interactions like closing modals
2. **Turbo caching** requires resetting the page before navigation to avoid showing manipulated state in cached preview

### Solution: Template-Based Restoration

Use HTML `<template>` elements to preserve and restore markup.

### Implementation Pattern

**HTML Structure:**
```html
<div data-controller="modal">
  <!-- Store original markup in template -->
  <template data-modal-target="template">
    <div class="modal">
      <div class="modal-content">
        <h2>Modal Title</h2>
        <p>Modal content here</p>
        <button data-action="click->modal#hide">Close</button>
      </div>
    </div>
  </template>

  <!-- Modal will be inserted here -->
</div>
```

**Controller Logic:**
```javascript
export default class extends Controller {
  static targets = ["template"]

  connect() {
    // Insert template content when controller initializes
    this.element.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
  }

  show(e) {
    e.preventDefault()
    // Just toggle visibility
    this.modalElement.classList.add("open")
  }

  hide(e) {
    e.preventDefault()
    // Remove manipulated modal
    this.element.removeChild(this.element.lastElementChild)
    // Restore from template
    this.element.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
  }

  get modalElement() {
    return this.element.querySelector(".modal")
  }
}
```

### Key Pattern

```javascript
// Remove manipulated DOM
this.element.removeChild(this.element.lastElementChild)

// Restore from template
this.element.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
```

### When to Use This Pattern

Best suited for:
- **Replacing larger portions of HTML** rather than simple CSS class toggles
- Third-party UI libraries that manipulate or remove your HTML
- Predictable DOM state before page transitions
- Turbo restoration visits requiring known initial states

### Limitations

May be unnecessary for:
- Simple DOM manipulations involving only CSS class changes
- Controllers that don't modify DOM structure
- Scenarios where `disconnect()` cleanup is sufficient

### insertAdjacentHTML Positions

```javascript
// Before the element itself
element.insertAdjacentHTML("beforebegin", html)

// Inside the element, before its first child
element.insertAdjacentHTML("afterbegin", html)

// Inside the element, after its last child
element.insertAdjacentHTML("beforeend", html)

// After the element itself
element.insertAdjacentHTML("afterend", html)
```

### Template Best Practices

1. **Keep templates minimal** - Only store what needs restoration
2. **Use targets** - Reference templates via Stimulus targets
3. **Clone, don't move** - Templates preserve original markup
4. **Consider performance** - innerHTML parsing has a cost
5. **Test edge cases** - Ensure event listeners are properly reattached

---

## Form Submits with Stimulus

### Use Case 1: Non-Button Form Submission

Submit forms without requiring users to click a submit button.

**Example: Submit on dropdown change**

```html
<form data-controller="form-auto-submit"
      action="/search"
      method="get">

  <select data-action="change->form-auto-submit#submit">
    <option value="">Select category...</option>
    <option value="books">Books</option>
    <option value="movies">Movies</option>
  </select>
</form>
```

```javascript
export default class extends Controller {
  submit(event) {
    event.preventDefault()
    // Use requestSubmit() to trigger proper form submission
    this.element.requestSubmit()
  }
}
```

**Why `requestSubmit()` instead of `submit()`?**

- `requestSubmit()` triggers the `submit` event (allows validation)
- `requestSubmit()` respects form validation
- `submit()` bypasses validation and event listeners

### Use Case 2: Intercepting Form Submissions

Execute custom client-side logic before form submission.

**Example: Modify form data before submit**

```html
<form data-controller="form-interceptor"
      data-action="submit->form-interceptor#intercept"
      action="/api/items"
      method="post">

  <input type="text" name="title" required>
  <input type="text" name="quantity" value="1">

  <button type="submit">Create Item</button>
</form>
```

```javascript
import { post } from "@rails/request.js"

export default class extends Controller {
  async intercept(event) {
    event.preventDefault()

    // Extract form data
    const formData = new FormData(this.element)

    // Perform client-side validation
    if (!this.validate(formData)) {
      return
    }

    // Append additional data
    formData.append("source", "web_form")
    formData.append("timestamp", new Date().toISOString())

    // Manually send request
    const response = await post(this.element.action, {
      body: formData,
      responseKind: "turbo-stream"
    })

    if (response.ok) {
      // Handle success
      this.element.reset()
    }
  }

  validate(formData) {
    const quantity = parseInt(formData.get("quantity"))
    if (quantity < 1 || quantity > 100) {
      alert("Quantity must be between 1 and 100")
      return false
    }
    return true
  }
}
```

### Common Patterns

**Submit on Enter in textarea:**
```html
<textarea data-action="keydown->form#submitOnEnter"></textarea>
```

```javascript
submitOnEnter(e) {
  if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
    e.preventDefault()
    this.element.requestSubmit()
  }
}
```

**Disable submit button during submission:**
```html
<form data-controller="form-submission"
      data-action="submit->form-submission#disableSubmit">
  <button type="submit"
          data-form-submission-target="submitButton">
    Submit
  </button>
</form>
```

```javascript
export default class extends Controller {
  static targets = ["submitButton"]

  disableSubmit(e) {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Submitting..."

    // Re-enable after a delay (if not using Turbo)
    setTimeout(() => {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Submit"
    }, 3000)
  }
}
```

**Confirm before submit:**
```html
<form data-controller="form-confirm"
      data-action="submit->form-confirm#confirm"
      data-form-confirm-message-value="Are you sure?">
  <button type="submit">Delete Account</button>
</form>
```

```javascript
export default class extends Controller {
  static values = {
    message: String
  }

  confirm(e) {
    if (!window.confirm(this.messageValue)) {
      e.preventDefault()
    }
  }
}
```

### Best Practices

1. **Use `requestSubmit()` not `submit()`** - Preserves validation and events
2. **Always preventDefault()** - When intercepting submission
3. **Handle loading states** - Disable buttons, show spinners
4. **Validate before submit** - Provide immediate feedback
5. **Reset forms after success** - Clear inputs for next submission
6. **Use @rails/request.js** - For Turbo compatibility
7. **Handle errors gracefully** - Show user-friendly error messages

---

## Turbo Integration Best Practices

### Form Submits with Turbo

When using Turbo, form submissions are automatically captured and handled via Turbo Drive.

**Default behavior:**
```html
<!-- Turbo intercepts this automatically -->
<form action="/items" method="post">
  <button type="submit">Submit</button>
</form>
```

**Opt out of Turbo:**
```html
<form action="/items" method="post" data-turbo="false">
  <button type="submit">Submit via full page load</button>
</form>
```

**Use Turbo Streams for updates:**
```html
<form action="/items"
      method="post"
      data-turbo-stream>
  <button type="submit">Submit</button>
</form>
```

Server response:
```erb
# items/create.turbo_stream.erb
<%= turbo_stream.append "items", @item %>
<%= turbo_stream.update "form", partial: "form" %>
```

### Turbo Frame integration

Scope form submission to a frame:

```html
<turbo-frame id="item-form">
  <form action="/items" method="post">
    <!-- Form only replaces content within this frame -->
    <button type="submit">Submit</button>
  </form>
</turbo-frame>
```

### Global Teardown (Already covered in lifecycle.md)

See the Lifecycle reference for details on implementing global teardown for Turbo caching.

### Turbo Events

Listen to Turbo events in Stimulus controllers:

```html
<div data-controller="turbo-aware"
     data-action="turbo:load@document->turbo-aware#refresh
                  turbo:before-cache@document->turbo-aware#cleanup">
</div>
```

```javascript
export default class extends Controller {
  refresh() {
    console.log("Page loaded via Turbo")
    // Reinitialize any state
  }

  cleanup() {
    console.log("About to cache page")
    // Remove dynamic classes, reset animations
  }
}
```

Common Turbo events:
- `turbo:click` - User clicked a link
- `turbo:before-visit` - About to navigate
- `turbo:visit` - Navigation started
- `turbo:load` - New page loaded
- `turbo:render` - Page rendered
- `turbo:before-cache` - About to cache current page
- `turbo:submit-start` - Form submission started
- `turbo:submit-end` - Form submission completed

### Turbo Streams with Stimulus

Update controller state from Turbo Stream actions:

```erb
# items/create.turbo_stream.erb
<%= turbo_stream.append "items" do %>
  <div data-controller="item"
       data-item-id-value="<%= @item.id %>">
    <%= @item.title %>
  </div>
<% end %>

<%= turbo_stream.replace "item-count" do %>
  <span id="item-count"
        data-controller="counter"
        data-counter-value="<%= @items.count %>">
    <%= @items.count %>
  </span>
<% end %>
```

The Stimulus controllers automatically connect when elements are inserted.
