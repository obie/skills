# Intent document template

The intent document is the statement of what the component must do and
why, written so an implementation can be produced from it plus the
contract spec, with no access to any previous implementation. It is the
"intent" and "compilation" primitives from chapter 3 in one file. Sources:
the current file's comments, the decision log from the survey agent, the
call sites, and vendor or runtime facts you can verify.

Write it before the contract spec. The contract spec then tests the
invariants; the intent explains them.

## Sections

### 1. Scope

Where the requirement applies. Name every caller by path and say what each
one does with the result. Say what is out of scope and why.

### 2. Environment facts (the compilation target)

Facts about the runtime, vendor, framework, and neighbors the code
compiles into. These are not the component's decisions. Group by source.
Where a fact was read from a binary or a vendor doc, say which version and
what to re-read when the pin moves. Publish the names of constants the
code must expose for these facts, because callers and specs refer to them.

Include the dependency API precisely: method names, return types, which
calls can raise, what a degenerate answer looks like (zero, a cap above
the window, a string where an integer is expected).

### 3. Public surface

A table of methods with signatures and return types, and the list of
published constants. This is the boundary. Nothing behind it is promised.

### 4. Invariants

Number them. Each has three parts:

- **Scope**: when it applies.
- **What must remain true**: stated at the boundary, in terms of inputs and
  outputs or emitted effects, never in terms of internal structure.
- **Why**: the incident, the constraint, the vendor behavior. Link the
  decision id. Name the legate, customer, or system that paid for the
  lesson; a future reader weighs a rule differently when it has a casualty
  attached.

Negative constraints first: what the component must never do. Then
ordering constraints (a filling session must hit the recoverable guard
before the hard one). Then resolution rules (where numbers come from, in
what order, what counts as no answer). Then non-functional promises (at
most one read of a shared cache per call). Then degenerate-input rules.

Mark time-bound invariants as such, with the condition that expires them.

### 5. Decisions the implementation compiles into

A table: decision id, value, one-line reason. Below it, the derivation for
each decision that a regenerator would otherwise have to guess: why this
fraction and not the next one, why this ceiling clears the observed bound
and the next candidate did not. In the first run every arm asked for the
derivations even though the values were given. Then a worked example the
decisions must reproduce exactly, so the regenerator can check itself.

### 6. Known limits

What is deliberately not fixed, with the reason. Single-observation
evidence. Pins that move.

## The sparse variant

Copy the document, delete section 5, replace every decision value in the
invariants with "a value you must choose that satisfies the invariants",
and remove every decision id reference. Then grep the result for each
value and id, including multi-line parenthetical references. Tell the
sparse arm that decisions are withheld and that it must record why it
chose what it chose.

## Membership test for every sentence

Would this sentence still be true after a reimplementation in another
language, framework, or shape? If it names a method, a call order, or a
data structure of the current code, it is implementation documentation and
belongs in the code's comments or nowhere.

## Skeleton

```markdown
# Intent: `Namespace::Component`

## 1. Scope
## 2. Environment facts (the compilation target)
### 2.1 <runtime>   ### 2.2 <vendor>   ### 2.3 <this app>
## 3. Public surface
| Method | Returns |
Published constants: ...
## 4. Invariants
**I1. <name>.** <scope>. <what must remain true>. Why: <reason>. (decision `<id>`)
...
## 5. Decisions the implementation compiles into
| Decision | Value | One-line reason |
Derivations: ...
Worked example: ...
## 6. Known limits
```
