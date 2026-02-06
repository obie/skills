# Lifecycle Best Practices

## Don't Overuse `connect`

### Primary Use Cases for `connect`

The `connect` lifecycle callback is **the correct place to instantiate any 3rd party plugins**, such as:
- Swiper
- Dropzone
- Chart.js
- Three.js
- Date pickers
- Rich text editors

It's also appropriate for:
- DOM preconditions based on browser capabilities
- Feature detection and polyfill setup
- One-time initialization that can't be handled declaratively

### What NOT to Do in `connect`

#### 1. Avoid Setting Up Controller State

**Bad:**
```javascript
export default class extends Controller {
  connect() {
    this.open = false;  // Don't initialize state here
  }
}
```

**Good:**
```javascript
export default class extends Controller {
  static values = {
    open: Boolean
  }

  openValueChanged(isOpen) {
    // React to state changes
    if (isOpen) {
      this.element.classList.add("open");
    }
  }
}
```

Use the Values API for state management instead.

#### 2. Avoid Adding Event Listeners

**Bad:**
```javascript
export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.handleClick.bind(this));
  }

  handleClick(e) {
    // ...
  }
}
```

**Good:**
```html
<div data-controller="example"
     data-action="click->example#handleClick">
</div>
```

```javascript
export default class extends Controller {
  handleClick(e) {
    // ...
  }
}
```

Regular Stimulus DOM notation for listeners will automatically clean up after themselves.

### Complete Example

**Bad Approach:**
```javascript
export default class extends Controller {
  connect() {
    // Multiple concerns mixed together
    this.open = false;
    this.element.addEventListener("click", this.toggle.bind(this));
  }

  toggle() {
    this.open = !this.open;
    this.element.classList.toggle("open", this.open);
  }
}
```

**Good Approach:**
```javascript
export default class extends Controller {
  static values = {
    open: Boolean
  }

  toggle() {
    this.openValue = !this.openValue;
  }

  openValueChanged(isOpen) {
    this.element.classList.toggle("open", isOpen);
  }
}
```

```html
<div data-controller="example"
     data-action="click->example#toggle"
     data-example-open-value="false">
</div>
```

### Rationale

Overloading `connect` can:
- Bloat the method and make it confusing to read
- Violate the Single Responsibility Principle by mixing different setup concerns
- Make testing more difficult
- Create cleanup issues if not properly paired with `disconnect`

### Important Caveat

These are guidelines, not absolute rules. Non-serializable instances (like Swiper objects or library instances) **do** require `connect` for initialization:

```javascript
import Swiper from 'swiper'

export default class extends Controller {
  connect() {
    this.swiper = new Swiper(this.element, {
      // configuration
    });
  }

  disconnect() {
    this.swiper.destroy();
  }
}
```

---

## Use Lifecycle Events for Setup and Teardown

### Key Concept

**"Using Stimulus lifecycle events allows you to make most JavaScript libraries compatible with Turbo without additional effort."**

Leverage the `connect()` method for setup and `disconnect()` for teardown operations.

### The Anti-Pattern

**Bad: Manual tracking with Turbo events**
```javascript
const editors = []

document.addEventListener('turbo:load', () => {
  document.querySelectorAll('[data-editor]').forEach(element => {
    const editor = new EasyMDE({ element })
    editors.push(editor)
  })
})

document.addEventListener('turbo:before-cache', () => {
  editors.forEach(editor => editor.toTextArea())
  editors.length = 0
})
```

Issues:
- Requires maintaining an external array of active instances
- Manual tracking overhead
- Global state management
- Difficult to configure per-instance

### The Recommended Approach

**Good: Wrap within a Stimulus controller**
```javascript
import EasyMDE from "easymde"

export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.editor = new EasyMDE({
      element: this.fieldTarget,
      // Pull configuration from data attributes
      spellChecker: this.element.dataset.spellCheck === "true"
    })
  }

  disconnect() {
    this.editor.toTextArea()
    this.editor = null
  }
}
```

```html
<div data-controller="markdown-editor"
     data-spell-check="true">
  <textarea data-markdown-editor-target="field"></textarea>
</div>
```

### Advantages

1. **Automatic instance management**
   - Stimulus creates separate controller instances automatically
   - No need for manual tracking or global arrays

2. **Configuration flexibility**
   - Each instance can pull unique settings from data attributes
   - Easy to have different configurations per element

3. **Lifecycle alignment**
   - Setup and cleanup are paired with element lifecycle
   - No orphaned instances or memory leaks

4. **Turbo compatibility**
   - No special Turbo integration code needed
   - Works automatically with page caching and restoration

### Common Libraries Pattern

```javascript
// Chart.js example
import Chart from 'chart.js'

export default class extends Controller {
  static values = {
    type: String,
    data: Object
  }

  connect() {
    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: this.dataValue
    })
  }

  disconnect() {
    this.chart.destroy()
    this.chart = null
  }
}
```

### Limitations

**Not all JavaScript libraries have good teardown methods** to remove their functionality from the page. For libraries without proper cleanup:

1. Check documentation for destroy/cleanup methods
2. Manually remove event listeners
3. Clear DOM modifications
4. Set instance references to null

### Best Practices

1. **Always pair connect with disconnect** - If you initialize in connect, clean up in disconnect
2. **Nullify references** - Set instance properties to null after cleanup
3. **Check for existing instances** - Prevent double initialization
4. **Use data attributes for config** - Make instances configurable
5. **Test lifecycle** - Verify cleanup happens correctly

---

## Global Teardown (Turbo-Specific)

### The Problem

When using Turbo, pages are cached before navigation. Upon returning, the cached version displays first before refreshing. This causes **"a flash of manipulated content"** if controllers modified the DOM before caching occurred.

### The Solution

Add a `teardown` method to controllers that manipulate the DOM. Then implement a global listener:

```javascript
// app/javascript/application.js
import { Application } from "@hotwired/stimulus"

const application = Application.start()

document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(controller => {
    if (typeof controller.teardown === 'function') {
      controller.teardown()
    }
  })
})
```

### Example Controller Implementation

```javascript
export default class extends Controller {
  connect() {
    this.element.classList.add('play-animation')
  }

  disconnect() {
    // Regular cleanup
  }

  teardown() {
    // Turbo-specific cleanup before caching
    this.element.classList.remove('play-animation')
  }
}
```

### Why This Approach?

While Stimulus controllers already have `disconnect`, separating Turbo-specific teardown into its own lifecycle method provides clarity:

**"There's exactly one place where that rollback should happen, and every controller can opt in."**

### Important Caveat

This approach isn't without debate. Since `disconnect` already exists for cleanup, implementing both methods could introduce unnecessary duplication depending on your application's Turbo usage intensity.

### When to Use

Use `teardown` when:
- Your controller adds CSS classes for animations
- You modify DOM structure temporarily
- You want to reset visual state before caching
- The change would look wrong in cached preview

Don't use `teardown` for:
- Regular event listener cleanup (use `disconnect`)
- Library destruction (use `disconnect`)
- State reset (happens automatically with new page load)
