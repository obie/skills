# Intent document template

The intent document is the statement of what the component must do and
why, written so an implementation can be produced from it plus the
contract spec, with no access to any previous implementation. It is the
"intent" and "compilation" primitives from chapter 3 in one file. Sources:
the current file's comments, the decision log from the survey agent, the
call sites, and vendor or runtime facts you can verify.

Write it before the contract spec. The contract spec then tests the
invariants; the intent explains them.

## Revision log

Once the intent has driven a shipped regeneration, the next change edits
this document again rather than starting over. Keep a log at the top:
one line per revision, what changed and why. A regenerator reading
revision 4 cold cannot see the questions that produced it unless the log
says so, and the log is also how a reviewer checks that a change was made
in the intent first rather than patched into the generated code.

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

**Type rules.** "Numeric" is not a type rule. Say Integer, and say what
happens to every other input: a Float, a String, a stringified number.
Say it separately for every source the value can arrive from (a catalog
answer, a stored profile value, a caller argument): a regenerator will
apply a stated rule to the source it was stated for and guess about the
others, and different regenerators guess differently.

State any persisted format here as a fact, not a decision, and give it
exactly: a cache key, a queue name, a file path, a serialized shape, an
env var's spelling, anything a previous deploy wrote or another process
reads. These pass the membership test that separates facts from decisions
(would another language need it anyway) and would still get invented fresh,
each internally consistent, by every regeneration that only has a
description of the shape to go on. Say what wrote it and what still reads
it, so a regenerator understands why the exact spelling is not theirs to
pick.

### 3. Public surface

A table of methods with signatures and return types, and the list of
published constants. This is the boundary. Nothing behind it is promised.

Before writing the published-constants list, grep every caller for
`Module::CONSTANT`. An omission here survives revision after revision: a
regenerator that finds the call site publishes the constant anyway and
asks in its notes whether the omission was deliberate, and the question
gets answered the same way every round unless someone runs the grep.

### 4. Invariants

Number them. Each has three parts:

- **Scope**: when it applies.
- **What must remain true**: stated at the boundary, in terms of inputs and
  outputs or emitted effects, never in terms of internal structure.
- **Why**: the incident, the constraint, the vendor behavior. Link the
  decision id. Name the profile, customer, or system that paid for the
  lesson; a future reader weighs a rule differently when it has a casualty
  attached.

Negative constraints first: what the component must never do. Then
ordering constraints (a filling session must hit the recoverable guard
before the hard one). Then resolution rules (where numbers come from, in
what order, what counts as no answer). Then non-functional promises (at
most one read of a shared cache per call, **including read order**: when
two or more of those reads are independent and either can fail on its
own, say which one happens first and why, since that order decides which
value survives a partial failure and a grid of inputs where every read
succeeds cannot surface the wrong order). Then degenerate-input rules.

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
