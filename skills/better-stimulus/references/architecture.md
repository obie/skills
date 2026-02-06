# Architecture Patterns

## Configurable Controllers

### Principle
Make Stimulus controllers reusable by externalizing hardcoded values into configurable dataset properties rather than embedding them in the controller logic.

### The Problem
```javascript
// Bad: Hardcoded values
export default class extends Controller {
  toggle(e) {
    e.preventDefault();
    this.element.classList.toggle("active");
  }
}
```

This tightly couples the class name to the controller, reducing flexibility.

### The Solution
Move dependencies to HTML data attributes:

```html
<a href="#"
   data-controller="toggle"
   data-action="click->toggle#toggle"
   data-toggle-active-class="active">
  Toggle
</a>
```

```javascript
export default class extends Controller {
  static classes = ["active"];

  toggle(e) {
    e.preventDefault();
    this.element.classList.toggle(this.activeClass);
  }
}
```

### Benefits
- **Late binding of dependencies** ensures controllers are reusable across multiple use cases
- Enables CSS classes, element IDs, and selectors to be injected
- Controllers obey the Single Responsibility Principle
- Remain adaptable across different contexts

---

## Application Controller

### Principle
Use JavaScript class inheritance to create a foundational base controller that all other controllers inherit from.

### Core Concept
ApplicationController serves as the foundation, allowing you to:
- Reduce boilerplate code across multiple controllers
- Centralize lifecycle callback methods
- Share common functionality application-wide

### Implementation
```javascript
// application_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  sayHi() {
    console.log("Hello from ApplicationController")
  }
}
```

```javascript
// custom_controller.js
import ApplicationController from "./application_controller"

export default class extends ApplicationController {
  connect() {
    super.sayHi()
    console.log("Hello from CustomController")
  }
}
```

### Key Principle
**Inheritance isn't always the answer to share behavior.**

Before expanding ApplicationController, evaluate whether the code represents:
- **Specialization** ("is a" relationship) → Use inheritance
- **A role** ("acts as" relationship) → Use mixins
- **Properties** ("has a" relationship) → Use composition

### Recommendation
Avoid bloating ApplicationController with unrelated functionality. Choose the appropriate design pattern based on the relationship between classes.

---

## Mixins

### When to Use
Use mixins when you need to share behavior across Stimulus controllers that don't have an "is a" relationship.

### The Problem with Inheritance
```javascript
// Bad: Using inheritance for shared behavior
class OverlayController extends Controller {}
class DropdownController extends OverlayController {}
class FlyoutController extends OverlayController {}
```

Issues:
- JavaScript doesn't support multiple inheritance
- Can't inherit from two different parent classes simultaneously
- Inheritance hierarchies become unwieldy as applications grow

### The Mixin Solution
Extract shared functionality into a reusable mixin function:

```javascript
// overlay_mixin.js
export const useOverlay = controller => {
  Object.assign(controller, {
    showOverlay(e) {
      // Implementation
    },
    hideOverlay(e) {
      // Implementation
    }
  });
};
```

Apply mixins during the `connect` lifecycle:

```javascript
import { useOverlay } from "./overlay_mixin"

export default class extends Controller {
  connect() {
    useOverlay(this);
  }
}
```

### Decision Framework
- **"Is a" relationship** → Use inheritance
- **"Acts as a" relationship** → Use mixins
- **"Has a" relationship** → Use composition

### Beyond Mixins
Composition may be even better. For collaborators ("has a"), create a separate module and instantiate it in `connect`.

### Reference
See **Adrien Poly's Stimulus Use** library for real-world examples.

---

## Targetless Controllers

### Principle
Avoid mixing two types of controller behavior: controllers acting on their attached element vs. controllers acting on designated targets.

### The Problem
```javascript
// Bad: Mixed concerns
export default class extends Controller {
  static targets = ["indicator"]

  submit(e) {
    e.preventDefault();
    this.element.requestSubmit();  // Acting on this.element
    this.indicatorTarget.textContent = "Submitting...";  // Acting on target
  }
}
```

This violates the Single Responsibility Principle - the controller has multiple reasons to change.

### The Solution
Split responsibilities into separate controllers:

**Form Controller** - handles form submission:
```javascript
export default class extends Controller {
  submit(e) {
    e.preventDefault();
    this.element.requestSubmit();
  }
}
```

**Form Indicator Controller** - manages UI feedback:
```javascript
export default class extends Controller {
  static targets = ["indicator"]

  show(e) {
    this.indicatorTarget.textContent = "Submitting...";
  }
}
```

Controllers communicate via native DOM events:
```html
<form data-controller="form"
      data-action="submit->form#submit submit->form-indicator#show">
  <div data-controller="form-indicator">
    <span data-form-indicator-target="indicator"></span>
  </div>
</form>
```

### Key Takeaway
Ask: "What would require this controller to change?" If you identify separate reasons related to targets versus the element itself, decouple the logic. Use outlets or events for inter-controller communication.

This approach enhances:
- Testability
- Reusability
- Code clarity

---

## Namespaced Attributes

### Purpose
Work with arbitrary sets of HTML attributes that are namespaced to both a controller and identified as parameters.

### The Problem
Standard Stimulus doesn't provide straightforward methods to:
- Retrieve a list of available attributes
- Apply additional namespace criteria beyond the basic data accessor

### The Solution
Use namespaced data attributes for flexible parameter sets:

```html
<input data-controller="filter"
       data-filter-param-category="cats"
       data-filter-param-rating="5"
       data-filter-param-color="black"
       type="text"
       data-action="input->filter#update">
```

### Implementation
Process attributes by:
1. Converting the dataset to an object (rather than relying on Stimulus's data accessor)
2. Filtering for specific namespace patterns (attributes starting with "filterParam")
3. Extracting base names by removing the namespace prefix
4. Building query parameters for URL manipulation

```javascript
export default class extends Controller {
  update() {
    const params = Object.keys(this.element.dataset)
      .filter(key => key.startsWith('filterParam'))
      .map(key => {
        const name = key.slice(11); // Remove "filterParam" prefix
        const value = this.element.dataset[key];
        return `${name.toLowerCase()}=${value}`;
      })
      .join('&');

    // Use params for URL manipulation
  }
}
```

### Benefit
Enables flexible handling of multiple related configuration parameters without explicitly defining each one, providing a scalable pattern for parameter-driven controllers.

### Note
Adjust the slice value based on your controller identifier length.
