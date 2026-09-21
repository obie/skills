# The contract spec: durable evaluations

An evaluation suite has three layers (chapter 5). Ephemeral tests check
the current implementation's internal choices and are regenerated with it.
Live evaluations run against production. Durable evaluations describe
behavior at a boundary, independent of any implementation, and they are
the oracle a regeneration is judged against. The contract spec is the
durable layer, written as its own file beside the implementation spec.

## Membership test

Would reimplementing the component in another language invalidate this
assertion? If yes, it is an implementation test. Keep it in the original
spec; do not put it here.

Consequences of taking that seriously:

- No pinned output numbers for a given input shape. `421_200` for grok is
  a consequence of a margin decision, not a promise. Assert the property
  the decision was chosen to satisfy: blocker below wall, blocker above the
  observed live-session size, trigger positive.
- Constants the environment fixes (a runtime's buffer sizes, a vendor's
  rule) may be referenced by name, because they are facts, not decisions.
  Restate them in the spec header so the geometry is checkable without
  reading the subject.
- Decision values (a margin, a ceiling, a divisor) are deliberately
  unpinned. Write down which. A regeneration that changes one passes this
  spec and is caught only by the behavioral diff. That is a design choice
  you are making; make it explicitly.

## Structure that worked

```ruby
RSpec.describe Namespace::Component, "contract" do
  # Facts about the runtime, restated. Not the subject's decisions.
  CC_RESERVE_CAP = 20_000
  MIN_HEADROOM = 0.06

  def geometry(env, raw:)   # derive the guards CC would compute from what we emit
    ...
  end

  describe "silence" do          # I1, I2: when the component must say nothing
  describe "guard geometry" do   # I3-I6: properties over a grid of shapes
    RAWS = [ 32_768, 65_536, ..., 2_097_152 ]
    CAPS = [ nil, 4_096, ..., :raw, :twice_raw ]
    it "keeps X positive and below Y with headroom" do
      shapes.each { |model, raw, cap| ... expect(g[:blocker]).to be < g[:wall], "#{model}: #{g}" }
    end
  describe "live-session non-stranding (time-bound)"   # I7, with its expiry in a comment
  describe "surface consistency"   # I8: query methods agree with the env builder
  describe "resolution"            # I9-I11: where numbers come from, degenerate inputs
  describe "cost"                  # I12: at most one dependency read per call
end
```

Each `describe` maps to invariant numbers in the intent. Each example's
name states the promise. Failure messages carry the shape and the derived
numbers so a red example reads as a sentence.

## Grids beat examples

Mutation testing on the first run: the 39-example original spec killed
513 of 583 mutants; the 24-example property contract killed 523. Every
extra kill was the same shape. A pinned example fixes one point where a
property over a grid sweeps a line. The original tested the trigger only
for grok, where the reservation exceeded the runtime's reserve cap, so
mutating the `min` was invisible. The grid included a small no-cap shape
whose reservation sat under the cap, and the `min` mattered.

Build the grid from: sizes spanning the realistic range and one order
above and below; caps including nil, values under and over the ceiling,
equal to the window, and double the window; then run every property over
the cross product.

## Degenerate inputs

Zero, one, and two as sizes. A float and a string where an integer is
expected. A dependency that raises. A collaborator whose stored value is
zero. These are where every regeneration differed from the original in
the first run, and the original was wrong each time: it emitted an output
line of zero and a float on the wire. The contract had asserted only "no
window key" for the degenerate case and said nothing about the output key.
Assert both. When the contract is silent, a regeneration can get worse
there without anyone noticing.

## Non-functional promises

Latency ceilings, cost envelopes, at-most-once reads of a shared cache: if
the intent promises it, the contract asserts it. `expect(dependency).to
have_received(:read).once` is a durable evaluation. A warn-level log on
failure is a promise too; 24 of the 60 survivors in the first run were log
rewrites the contract let live because it had not asserted the log.

## Consistency across the surface

When a component exposes both a builder and query methods that report
what the builder would produce, assert that they agree for the same
inputs, and that the query is nil exactly when the builder omits the key.
A caller that caps its own threshold at the query number is depending on
that agreement.

## After mutation testing

Classify survivors (see `scoring.md`). For each survivor that is a real
gap, add the assertion now, before regeneration. In the first run three
additions took the contract from 89.7% to roughly 95% on the original
code: assert the warn log, assert no output key when no window key, and
run the surface-consistency example with the collaborator fallback.

## Keep the original spec

It is the "would the old oracle have accepted this" check in scoring, and
its pinned numbers are the behavioral diff in miniature. It is also where
the ephemeral layer lives. Regenerators must never see it.
