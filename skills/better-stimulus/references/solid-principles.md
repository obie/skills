# SOLID Principles in Stimulus

## Single Responsibility Principle

### Overview

Each Stimulus controller should have one reason to change. Avoid "page controllers" that bundle unrelated functionality.

### The Problem (Bad Approach)

```javascript
// page_controller.js - handles multiple concerns
export default class extends Controller {
  static targets = ["modal", "form"]

  openModal() {
    this.modalTarget.classList.add("open")
  }

  closeModal() {
    this.modalTarget.classList.remove("open")
  }

  submitForm() {
    this.formTarget.submit()
  }

  validateForm() {
    // Validation logic
  }
}
```

Issues:
- Couples unrelated behaviors (modal + form)
- Inflexible and tied to specific page structures
- Changes to modal logic affect form logic
- Difficult to reuse in other contexts
- Hard to test in isolation

### The Solution (Good Approach)

Separate concerns into focused, single-purpose controllers:

```javascript
// modal_controller.js
export default class extends Controller {
  open() {
    this.element.classList.add("open")
  }

  close() {
    this.element.classList.remove("open")
  }
}
```

```javascript
// form_controller.js
export default class extends Controller {
  submit(e) {
    e.preventDefault()
    if (this.validate()) {
      this.element.submit()
    }
  }

  validate() {
    // Validation logic
    return true
  }
}
```

HTML:
```html
<div data-controller="modal">
  <form data-controller="form"
        data-action="submit->form#submit">
    <!-- Form fields -->
  </form>
</div>
```

### Key Benefits

1. **Reusable**
   - `modal_controller` can be used on any modal element
   - `form_controller` can be used on any form element
   - Controllers are context-independent

2. **Maintainable**
   - Changes occur in one location
   - Reduced implementation costs
   - Easier to understand and debug
   - Clear separation of concerns

### Testing the Principle

Ask yourself: **"What would cause this controller to change?"**

If you identify multiple, unrelated reasons (e.g., "modal behavior changed" AND "form validation changed"), split the controller.

### References

- *Practical Object Oriented Design* by Sandi Metz
- Wikipedia's Single Responsibility Principle entry

---

## Open-Closed Principle

### Overview

**"Software entities should be closed for modification, but open to extension."**

This principle enables changes without causing pain throughout a codebase.

### The Problem (Bad Approach)

```javascript
// widget_controller.js - requires modification for each new widget type
export default class extends Controller {
  static values = {
    type: String
  }

  async connect() {
    switch(this.typeValue) {
      case "toggle":
        this.toggledValue = false
        break
      case "dropdown":
        this.options = await fetch(`/api/options`)
        break
      case "slider":
        this.min = 0
        this.max = 100
        break
      // More cases...
    }
  }
}
```

Issues:
- Adding new widget types requires modifying the base class
- State properties become cluttered with multiple widget-specific variables
- Child classes risk breaking when the base class is altered
- Switch statement grows indefinitely
- Violates "closed for modification"

### The Solution (Good Approach)

Use inheritance and polymorphism:

```javascript
// widget_controller.js - base class
export default class WidgetController extends Controller {
  connect() {
    this.setup()
  }

  setup() {
    // Base setup logic
  }
}
```

```javascript
// toggle_controller.js
import WidgetController from "./widget_controller"

export default class extends WidgetController {
  static values = {
    toggled: Boolean
  }

  setup() {
    super.setup()
    // Toggle-specific setup
  }
}
```

```javascript
// dropdown_controller.js
import WidgetController from "./widget_controller"

export default class extends WidgetController {
  static values = {
    options: Array
  }

  async setup() {
    super.setup()
    this.optionsValue = await fetch(`/api/options`).then(r => r.json())
  }
}
```

HTML:
```html
<!-- Use specific controller for each widget type -->
<div data-controller="toggle" data-toggle-toggled-value="false"></div>
<div data-controller="dropdown"></div>
<div data-controller="slider"></div>
```

### Benefits

- **Closed for modification**: Base class remains stable
- **Open to extension**: New widgets extend the base
- **State isolation**: Each widget has its own properties
- **No switch statements**: Polymorphism handles differences
- **Easier testing**: Test each widget type independently

### When to Apply

Consider this principle when:
- You have multiple variants of similar functionality
- You find yourself adding cases to switch statements
- Adding features requires modifying existing code
- You need to support plugins or extensions

### Key Takeaway

Specialization through inheritance and method overriding allows systems to grow without requiring constant modification of existing code—the essence of sustainable software design.

---

## Dependency Inversion Principle

### Overview

The Dependency Inversion Principle (DIP) emphasizes that software modules should **"depend upon abstractions, not concretes."**

This creates loose coupling between components, making systems more flexible and maintainable.

### The Problem: Tight Coupling

```javascript
// search_controller.js - tightly coupled to GoogleAPI
import { GoogleAPI } from "./google_api"

export default class extends Controller {
  connect() {
    this.searchAPI = new GoogleAPI()
  }

  async search(query) {
    const results = await this.searchAPI.search(query)
    this.displayResults(results)
  }
}
```

Issues:
- **Locked to a specific implementation**
- Adding alternative services (Algolia, Elasticsearch) requires creating entirely new controllers
- Creates "shotgun surgery"—cascading changes across the codebase
- Testing requires mocking the specific API
- No flexibility to switch providers

### The Solution: Dynamic Imports with Stimulus Values

Use Stimulus values to specify which service to load:

```javascript
// search_controller.js - depends on abstraction
export default class extends Controller {
  static values = {
    api: String
  }

  async apiValueChanged(apiValue) {
    if (apiValue === "google") {
      const module = await import("./google_api")
      this.searchAPI = new module.GoogleAPI()
    } else if (apiValue === "algolia") {
      const module = await import("./algolia_api")
      this.searchAPI = new module.AlgoliaAPI()
    } else if (apiValue === "elasticsearch") {
      const module = await import("./elasticsearch_api")
      this.searchAPI = new module.ElasticsearchAPI()
    }
  }

  async search(query) {
    const results = await this.searchAPI.search(query)
    this.displayResults(results)
  }
}
```

HTML configuration:
```html
<!-- Switch API providers via data attribute -->
<div data-controller="search" data-search-api-value="google">
  <input type="search" data-action="input->search#search">
</div>

<!-- Different page, different provider -->
<div data-controller="search" data-search-api-value="algolia">
  <input type="search" data-action="input->search#search">
</div>
```

### API Interface Contract

All API implementations must provide the same interface:

```javascript
// google_api.js
export class GoogleAPI {
  async search(query) {
    // Google-specific implementation
    return results
  }
}

// algolia_api.js
export class AlgoliaAPI {
  async search(query) {
    // Algolia-specific implementation
    return results
  }
}
```

The controller depends on the `search(query)` method signature, not the concrete implementation.

### Key Benefits

1. **Single point of change**
   - Adding new services requires only updating the conditional logic
   - No need to modify consuming code

2. **Runtime flexibility**
   - API implementations can switch without page reloads
   - A/B testing different providers becomes trivial

3. **Interface consistency**
   - All services simply need matching method signatures
   - Controller remains agnostic about specific implementations

4. **Reduced coupling**
   - Controller doesn't import or instantiate specific APIs
   - Dependencies are injected via configuration

5. **Better testing**
   - Easy to swap in mock implementations
   - Test controller logic independently of API choice

### Alternative: Dependency Injection

For more complex scenarios, use a factory or registry:

```javascript
// api_registry.js
const APIs = {
  google: () => import("./google_api").then(m => new m.GoogleAPI()),
  algolia: () => import("./algolia_api").then(m => new m.AlgoliaAPI()),
  elasticsearch: () => import("./elasticsearch_api").then(m => new m.ElasticsearchAPI())
}

export async function createAPI(type) {
  const factory = APIs[type]
  if (!factory) {
    throw new Error(`Unknown API type: ${type}`)
  }
  return await factory()
}
```

```javascript
// search_controller.js
import { createAPI } from "./api_registry"

export default class extends Controller {
  static values = {
    api: String
  }

  async apiValueChanged(apiValue) {
    this.searchAPI = await createAPI(apiValue)
  }
}
```

### When to Apply

Use dependency inversion when:
- You have multiple implementations of the same concept
- You need to switch implementations at runtime
- You want to support plugins or extensions
- Testing requires mocking dependencies
- You need to support different environments (dev/staging/prod)

### Relationship to Stimulus

This principle respects Stimulus's inversion-of-control architecture:
- Configuration lives in HTML (data attributes)
- Controllers respond to configuration
- Implementation details are hidden from markup

---

## Combining SOLID Principles

### Example: Search Feature

Apply all three principles together:

```javascript
// Base search controller (Open-Closed)
export default class SearchController extends Controller {
  static values = {
    api: String  // Dependency Inversion
  }

  async apiValueChanged(apiValue) {
    this.searchAPI = await createAPI(apiValue)
  }

  async search(query) {
    const results = await this.searchAPI.search(query)
    this.dispatch('results', { detail: { results } })
  }
}

// Results display controller (Single Responsibility)
export default class SearchResultsController extends Controller {
  static targets = ['container']

  show(event) {
    const { results } = event.detail
    this.containerTarget.innerHTML = this.renderResults(results)
  }

  renderResults(results) {
    return results.map(r => `<div>${r.title}</div>`).join('')
  }
}
```

HTML:
```html
<div data-controller="search" data-search-api-value="google">
  <input type="search" data-action="input->search#search">
</div>

<div data-controller="search-results"
     data-action="search:results->search-results#show">
  <div data-search-results-target="container"></div>
</div>
```

### Benefits of Combined Approach

- **Single Responsibility**: Search logic and display logic are separate
- **Open-Closed**: Can add new search providers without modifying controllers
- **Dependency Inversion**: Search provider is configurable, not hardcoded

Result: Flexible, maintainable, testable code.
