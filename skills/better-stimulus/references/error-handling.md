# Error Handling

## Global Error Handler

### Purpose

Centralize error management for Stimulus controllers to capture both Stimulus-internal errors and application-level exceptions.

### Core Concept

Create a unified handler that:
- Captures error context (controller identifier, user ID, etc.)
- Passes errors to Stimulus application's built-in error handler
- Enables consistent error reporting
- Integrates with error tracking services (Sentry, Honeybadger, etc.)

### Implementation

#### Step 1: Create Application Controller

```javascript
// application_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  handleError(error, message = null) {
    // Build error context
    const context = {
      controller: this.identifier,
      element: this.element.outerHTML.slice(0, 200), // First 200 chars
      userId: document.body.dataset.userId,
      url: window.location.href,
      timestamp: new Date().toISOString()
    }

    // Add custom message if provided
    if (message) {
      console.error(`${message}:`, error, context)
    } else {
      console.error("Controller error:", error, context)
    }

    // Pass to Stimulus error handler
    this.application.handleError(error, `Error in ${this.identifier} controller`, context)
  }
}
```

#### Step 2: Use in Child Controllers

```javascript
// example_controller.js
import ApplicationController from "./application_controller"

export default class extends ApplicationController {
  async fetchData() {
    try {
      const response = await fetch("/api/data")
      if (!response.ok) throw new Error("Fetch failed")
      return await response.json()
    } catch (error) {
      this.handleError(error, "Failed to fetch data")
      // Optionally show user-friendly message
      this.showErrorMessage("Could not load data. Please try again.")
    }
  }

  processData(data) {
    try {
      // Complex processing logic
      return data.map(item => this.transform(item))
    } catch (error) {
      this.handleError(error, "Failed to process data")
      return []
    }
  }
}
```

### Integration with Error Tracking Services

#### Sentry Integration

```javascript
// application.js
import { Application } from "@hotwired/stimulus"
import * as Sentry from "@sentry/browser"

const application = Application.start()

// Store default handler
const defaultErrorHandler = application.handleError.bind(application)

// Override with custom handler
application.handleError = function(error, message, detail = {}) {
  // Report to Sentry
  Sentry.captureException(error, {
    contexts: {
      stimulus: {
        message: message,
        ...detail
      }
    }
  })

  // Call default handler to maintain console logging
  defaultErrorHandler(error, message, detail)
}
```

#### Honeybadger Integration

```javascript
// application.js
import { Application } from "@hotwired/stimulus"
import Honeybadger from "@honeybadger-io/js"

const application = Application.start()

// Store default handler
const defaultErrorHandler = application.handleError.bind(application)

// Override with custom handler
application.handleError = function(error, message, detail = {}) {
  // Report to Honeybadger
  Honeybadger.notify(error, {
    context: {
      stimulus_controller: detail.controller,
      stimulus_message: message,
      ...detail
    }
  })

  // Call default handler
  defaultErrorHandler(error, message, detail)
}
```

### Error Handling Patterns

#### Graceful Degradation

```javascript
export default class extends ApplicationController {
  static targets = ["content", "error"]

  async connect() {
    try {
      await this.loadContent()
    } catch (error) {
      this.handleError(error)
      this.showFallback()
    }
  }

  showFallback() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.remove("hidden")
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.add("hidden")
    }
  }
}
```

#### Retry Logic

```javascript
export default class extends ApplicationController {
  static values = {
    maxRetries: { type: Number, default: 3 },
    retryDelay: { type: Number, default: 1000 }
  }

  async fetchWithRetry(url, retries = 0) {
    try {
      const response = await fetch(url)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return await response.json()
    } catch (error) {
      if (retries < this.maxRetriesValue) {
        await this.delay(this.retryDelayValue * (retries + 1))
        return this.fetchWithRetry(url, retries + 1)
      } else {
        this.handleError(error, `Failed after ${retries} retries`)
        throw error
      }
    }
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}
```

#### User-Friendly Error Messages

```javascript
export default class extends ApplicationController {
  static targets = ["errorMessage"]

  handleUserError(error, userMessage) {
    // Log technical error
    this.handleError(error)

    // Show user-friendly message
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = userMessage
      this.errorMessageTarget.classList.remove("hidden")

      // Auto-hide after 5 seconds
      setTimeout(() => {
        this.errorMessageTarget.classList.add("hidden")
      }, 5000)
    }
  }

  async submitForm(e) {
    e.preventDefault()

    try {
      await this.sendData()
      this.showSuccess("Form submitted successfully!")
    } catch (error) {
      this.handleUserError(
        error,
        "We couldn't submit your form. Please check your connection and try again."
      )
    }
  }
}
```

### Strategic Benefits

By funneling all errors through a single pathway, you gain:

1. **Consistent contextual information** across error reports
2. **Simplified integration** with monitoring services
3. **Unified error handling** whether issues originate from Stimulus or custom code
4. **Better debugging** with consistent error format
5. **User experience control** - decide how to handle errors globally

### Best Practices

1. **Always use try-catch** for async operations
2. **Provide context** - Include relevant data with errors
3. **Don't swallow errors** - Always log or report them
4. **User-friendly messages** - Separate technical errors from user messages
5. **Test error paths** - Verify error handling works correctly
6. **Monitor in production** - Use error tracking services
7. **Handle network failures** - Assume API calls will fail
8. **Set timeouts** - Don't wait forever for responses

### Testing Error Handlers

```javascript
// test/controllers/example_controller_test.js
import { Application } from "@hotwired/stimulus"
import ExampleController from "../../javascript/controllers/example_controller"

describe("ExampleController", () => {
  let application
  let errorSpy

  beforeEach(() => {
    application = Application.start()
    application.register("example", ExampleController)

    // Spy on error handler
    errorSpy = jest.spyOn(application, "handleError")
  })

  it("handles fetch errors", async () => {
    // Mock failed fetch
    global.fetch = jest.fn(() =>
      Promise.reject(new Error("Network error"))
    )

    const controller = application.getControllerForElementAndIdentifier(
      document.createElement("div"),
      "example"
    )

    await controller.fetchData()

    expect(errorSpy).toHaveBeenCalledWith(
      expect.any(Error),
      expect.stringContaining("Failed to fetch"),
      expect.any(Object)
    )
  })
})
```

### Error Handler Checklist

- [ ] Create ApplicationController with handleError method
- [ ] All controllers extend ApplicationController
- [ ] Try-catch blocks wrap risky operations
- [ ] Error context includes controller identifier
- [ ] User-friendly messages shown for user-facing errors
- [ ] Error tracking service integrated
- [ ] Default error handler preserved
- [ ] Error handling tested
- [ ] Network timeouts configured
- [ ] Retry logic for transient failures
