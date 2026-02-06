# State Management with the Values API

## Core Principle
Use Stimulus values for controller state management in nearly all situations, rather than direct property assignment.

## The Problem with Direct Property Assignment

```javascript
// Bad: Instance properties lack reactivity
export default class extends Controller {
  connect() {
    this.markers = [];
  }

  addMarker() {
    this.markers.push({...})
  }
}
```

Issues:
- Lacks proper reactivity
- Creates maintenance problems
- No automatic change detection
- State is not persisted in DOM

## The Recommended Solution

Use Stimulus's built-in values system:

```javascript
// Good: Use Stimulus values
export default class extends Controller {
  static values = {
    markers: Array
  }

  addMarker() {
    this.markersValue.push({...});
  }

  markersValueChanged(markers, previousMarkers) {
    // Automatic callback when markers change
    this.map.updateMarkers(markers);
  }
}
```

HTML:
```html
<div data-controller="map"
     data-map-markers-value="[]">
</div>
```

## Key Rationale

**"Stimulus values being serialized and stored in the DOM itself provides the single source of truth."**

### Three Major Advantages

1. **External mutation capability**
   - State can be modified via Turbo Streams or morphs
   - Other controllers or server responses can update values
   - Changes propagate automatically

2. **DOM integration**
   - Works seamlessly with Turbo Caching
   - State is preserved across page navigation
   - No memory leaks from orphaned controllers

3. **Reactivity**
   - Automatic callbacks trigger when values change
   - Use `[valueName]ValueChanged(newValue, oldValue)` callbacks
   - No need for manual change detection

## Value Types

Stimulus supports these value types:
- `Array`
- `Boolean`
- `Number`
- `Object`
- `String`

```javascript
static values = {
  url: String,
  count: Number,
  enabled: Boolean,
  items: Array,
  config: Object
}
```

## Important Limitations

Values may be unsuitable in two situations:

1. **Non-serializable objects**
   - Objects that don't match built-in types
   - Class instances (like `Date`, `Map`, `Set`)
   - Functions or callbacks
   - DOM elements

2. **Sensitive data**
   - Data inappropriate for HTML exposure
   - API keys or tokens
   - User credentials
   - Private information

For these cases, use instance properties but be aware of the tradeoffs in reactivity and persistence.

## Default Values

Provide defaults in the value definition:

```javascript
static values = {
  count: { type: Number, default: 0 },
  enabled: { type: Boolean, default: true }
}
```

## Reading and Writing Values

```javascript
// Read
const count = this.countValue;

// Write (triggers callback)
this.countValue = 42;

// Check if attribute exists
if (this.hasCountValue) {
  // ...
}
```

## Change Callbacks

Implement `[name]ValueChanged` to react to changes:

```javascript
countValueChanged(newValue, oldValue) {
  console.log(`Count changed from ${oldValue} to ${newValue}`);
  this.updateDisplay();
}
```

Callbacks fire:
- When the controller connects and the attribute exists
- Whenever the value changes via `this.countValue = ...`
- When external code modifies the data attribute

## Best Practices

1. **Default to values** - Use values unless you have a specific reason not to
2. **Embrace reactivity** - Leverage change callbacks instead of manual checks
3. **Keep values simple** - Stick to serializable data
4. **Use defaults** - Provide sensible default values
5. **Document value types** - Make the static values declaration clear

## External Updates

Values can be updated from anywhere:

**From Turbo Streams:**
```erb
<%= turbo_stream.update "map" do %>
  <div data-controller="map"
       data-map-markers-value="<%= @markers.to_json %>">
  </div>
<% end %>
```

**From JavaScript:**
```javascript
element.dataset.mapMarkersValue = JSON.stringify(newMarkers);
```

**From other controllers:**
```javascript
const mapController = this.application.getControllerForElementAndIdentifier(
  mapElement,
  "map"
);
mapController.markersValue = newMarkers;
```
