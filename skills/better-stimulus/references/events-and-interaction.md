# Events and Controller Interaction

## Events Best Practices

### Key Principle

**Register global events declaratively in markup rather than programmatically in controller code.**

This allows Stimulus to manage event listener lifecycle automatically.

### Recommended Approach

Use `data-action` attributes for global events:

```html
<div data-controller="gallery"
     data-action="resize@window->gallery#layout">
  ...
</div>
```

```javascript
export default class extends Controller {
  layout(e) {
    // Handle resize event
  }
}
```

### Why This Matters

**"A Stimulus controller can `connect` / `disconnect` an arbitrary number of times."**

If listeners added during `connect` aren't cleaned up on `disconnect`:
- Duplicate listeners accumulate
- Callbacks fire multiple times
- Memory leaks occur
- Debugging becomes difficult

### Common Global Events

```html
<!-- Window events -->
<div data-action="resize@window->controller#handleResize">
<div data-action="scroll@window->controller#handleScroll">
<div data-action="click@window->controller#handleClickOutside">

<!-- Document events -->
<div data-action="keydown@document->controller#handleKeydown">
<div data-action="turbo:load@document->controller#refresh">
```

---

## Manual Event Management (When Required)

If you **must** add listeners programmatically, store the bound function reference.

### The Problem

```javascript
// Bad: Creates new function each time
connect() {
  document.addEventListener("click", this.findFoo.bind(this))
}

disconnect() {
  // This won't work - different function reference!
  document.removeEventListener("click", this.findFoo.bind(this))
}
```

Calling `.bind()` creates a new function each time, so the function added isn't the same as the one being removed.

### The Solution

**Store the bound reference:**

```javascript
export default class extends Controller {
  connect() {
    this.boundFindFoo = this.findFoo.bind(this)
    document.addEventListener("click", this.boundFindFoo)
  }

  disconnect() {
    document.removeEventListener("click", this.boundFindFoo)
  }

  findFoo(event) {
    // Implementation
  }
}
```

The bound reference must remain consistent for proper cleanup.

### Event Options

Add event options when needed:

```javascript
connect() {
  this.boundHandler = this.handleScroll.bind(this)
  window.addEventListener("scroll", this.boundHandler, { passive: true })
}

disconnect() {
  window.removeEventListener("scroll", this.boundHandler, { passive: true })
}
```

---

## Controller Communication: Outlets

### Overview

**Outlets** are an official Stimulus feature for enabling communication between different controllers. They allow one controller to invoke methods on another controller instance without direct coupling.

### When to Use Outlets

Use outlets for:
- Complex, data-rich interfaces (dashboards, data tables)
- Parent-child controller relationships
- Structured layouts with hierarchical controllers
- Controllers following Single Responsibility Principle that need cross-controller messaging

### Implementation Pattern

**HTML Structure:**
```html
<div data-controller="job-dashboard"
     data-job-dashboard-job-outlet=".job">

  <div class="job" data-controller="job">
    <h2 data-job-target="title">Job 1</h2>
  </div>

  <div class="job" data-controller="job">
    <h2 data-job-target="title">Job 2</h2>
  </div>
</div>
```

**Parent Controller:**
```javascript
// job_dashboard_controller.js
export default class extends Controller {
  static outlets = ['job']

  refreshAll() {
    // Access all job controller instances
    this.jobOutlets.forEach(outlet => {
      outlet.update({ status: 'refreshed' })
    })
  }

  // Check if outlets are connected
  jobOutletConnected(outlet, element) {
    console.log('Job outlet connected', outlet)
  }

  jobOutletDisconnected(outlet, element) {
    console.log('Job outlet disconnected', outlet)
  }
}
```

**Child Controller:**
```javascript
// job_controller.js
export default class extends Controller {
  static targets = ['title']

  update(data) {
    this.titleTarget.textContent = data.status
  }
}
```

### Outlet Properties and Methods

```javascript
// Single outlet (first match)
this.jobOutlet

// Multiple outlets (array)
this.jobOutlets

// Check existence
this.hasJobOutlet

// Outlet elements
this.jobOutletElement
this.jobOutletElements
```

### Best Practices

**Use outlets when:**
- Controllers follow Single Responsibility Principle
- You need cross-controller messaging in structured layouts
- Parent-child relationships are clear
- You want type-safe controller references

**Avoid outlets when:**
- Outlet selectors create bloated or confusing markup
- The relationship is temporary or dynamic
- Custom events would be simpler
- You're just passing data (consider events instead)

### Design Consideration

The main tradeoff involves markup complexity—maintaining selector references in HTML versus using event-driven communication patterns.

---

## Controller Communication: Callbacks

### Purpose

Use callbacks for inter-controller communication when multiple controllers need data from each other, instead of creating redundant event triggers.

### The Problem

Creating redundant event triggers for each interaction:
```javascript
// Bad: Multiple specific events
export default class extends Controller {
  connect() {
    this.element.addEventListener('needsUserData', this.sendUserData)
    this.element.addEventListener('needsConfigData', this.sendConfigData)
    // More and more events...
  }
}
```

### The Solution

Use a callback pattern where consumers request state from producers:

**Data Source Controller:**
```javascript
// user_controller.js
export default class extends Controller {
  static values = {
    name: String,
    email: String
  }

  connect() {
    this.element.addEventListener('user:request', (event) => {
      // Pass this controller instance to the callback
      event.detail.callback(this)
    })
  }
}
```

**Data Consumer Controller:**
```javascript
// form_controller.js
export default class extends Controller {
  connect() {
    // Request user data with a callback
    const event = new CustomEvent('user:request', {
      bubbles: true,
      detail: {
        callback: (userController) => {
          // Access user data
          console.log(userController.nameValue)
          console.log(userController.emailValue)
          this.populateForm(userController)
        }
      }
    })
    this.element.dispatchEvent(event)
  }

  populateForm(userController) {
    // Use the data
  }
}
```

### Key Benefits

- **Eliminates redundancy** when multiple controllers need the same data
- Provides **a common interface** for cross-controller communication
- Maintains single responsibility by letting each controller handle its own domain
- Reduces event proliferation in the application

### Important Caution

**This method should clarify communication purposes and avoid triggering actions across controllers**, which would violate Stimulus design principles of isolated component logic.

Use callbacks for:
- Reading state from other controllers
- Requesting configuration or data
- Querying system state

Don't use callbacks for:
- Triggering actions in other controllers (use events)
- Modifying other controller's state directly
- Creating tight coupling between controllers

---

## Custom Events Pattern

### Purpose

Use custom events for loose coupling between controllers when the sender doesn't need to know about receivers.

### Basic Pattern

**Dispatching Controller:**
```javascript
export default class extends Controller {
  submit(e) {
    e.preventDefault()

    const event = new CustomEvent('form:submitted', {
      bubbles: true,
      detail: { formData: new FormData(this.element) }
    })
    this.element.dispatchEvent(event)
  }
}
```

**Listening Controller:**
```html
<div data-controller="notification"
     data-action="form:submitted@window->notification#show">
</div>
```

```javascript
export default class extends Controller {
  show(event) {
    const { formData } = event.detail
    // Handle the event
  }
}
```

### Event Options

**bubbles: true** - Event propagates up the DOM tree
```javascript
new CustomEvent('name', { bubbles: true })
```

**cancelable: true** - Event can be cancelled with `preventDefault()`
```javascript
new CustomEvent('name', { cancelable: true })
```

**detail** - Pass data to event listeners
```javascript
new CustomEvent('name', {
  detail: { key: 'value' }
})
```

### When to Use Custom Events vs Outlets

| Custom Events | Outlets |
|--------------|---------|
| Loose coupling | Tight coupling |
| One-to-many | One-to-one or one-to-many |
| Don't know receivers | Know receivers |
| Broadcast pattern | Direct reference pattern |
| Simpler markup | More complex selectors |

### Best Practices

1. **Namespace event names** - Use prefixes like `form:submitted` or `modal:closed`
2. **Always bubble** - Set `bubbles: true` for flexibility
3. **Document event contracts** - What data is in `detail`?
4. **Keep detail simple** - Pass serializable data
5. **Use constants** - Define event names as constants to avoid typos

```javascript
// event_types.js
export const FORM_SUBMITTED = 'form:submitted'
export const MODAL_CLOSED = 'modal:closed'

// Usage
import { FORM_SUBMITTED } from './event_types'

this.element.dispatchEvent(
  new CustomEvent(FORM_SUBMITTED, { bubbles: true })
)
```
