# Scoring: the gates, the behavioral diff, and the mutation two-pass

Scoring answers two questions about each regenerated candidate: does it
keep every promise the oracles can state, and does it behave like the
original on every input anyone can think of. It also answers one question
about the oracles themselves: how much of the original code would they
notice being broken.

All scripts read a small `config.sh` you write per component (paths to
the app root, the implementation file, both specs, the candidates dir,
the probe, the baseline). Each script's header documents the variables.

## The gates, in order

`scripts/score.sh <config.sh> <arm>` swaps a candidate into the main tree
and runs four checks, then restores the original on exit whatever
happened. Never run two scores at once; they swap the same file.

1. **Contract spec.** Must be green. A red contract means the arm failed
   the bar and the rest is secondary.
2. **The original implementation spec.** The arm never saw it. Passing it
   is a strong equivalence signal. Failing it while the contract passes
   tells you exactly what the contract left unpinned.
3. **Lint.** Rubocop or the project's equivalent.
4. **Behavioral dump and diff.** `scripts/dump.rb <probe.rb> <impl>
   <out.json>` loads the candidate in place of the original constant,
   stubs the dependency per the probe, calls every public method over the
   probe's input grid, and writes sorted JSON. The scorer diffs it against
   `baseline.json` from the original and prints every differing input
   with both values.

Then `scripts/pairwise_diff.py` compares every pair of dumps, candidates
and baseline, and reports per-candidate differences outside the `edge/`
family. That number should be zero. If it is not, either the candidate
regressed on a realistic input or the contract has a gap the pairwise diff
just found.

## Building the grid (the probe)

The probe is a plain Ruby file with four methods: `stub!`,
`unload_and_load!`, `inputs`, and `call`. The dump runs against the real
app boot with only the dependency faked. Four sources of inputs, crossed
with collaborator and decoration variants:

- A synthetic grid: sizes spanning the realistic range plus one order
  above and below (in the first run 8_192 up to 2_097_152), crossed with
  caps of nil, several fixed values under and over the ceiling, equal to
  the size, and double the size.
- Real shapes fetched once from the live source with `scripts/shapes.rb`
  and saved as `shapes.json`, so the diff covers what production sees.
  Fetching them is also how you discover an expired decision premise;
  grok's completion cap had moved from 128k to 450k.
- Edge values the dependency can return: zero, negative, a string, a
  float, `nil`, and a stub that raises, each independently and together.
- Inputs to the component itself: blank, whitespace, the silenced family
  (Anthropic slugs in every spelling and decoration), unknown ids, and
  every id both bare and decorated.

Each input runs with no collaborator, with a collaborator carrying a
realistic stored value, and with one carrying zero. The first run had 490
inputs; the baseline had zero raises.

## Reading the diff

Every differing input is one of two things: a regression in the candidate,
or evidence the original was wrong on an input nobody had tested. Read
each one. In the first run all twelve differences were the second kind,
on three degenerate shapes (a one-token window, a two-token window, a
float cap), and the candidates' answers were better. That is still an
evaluation gap: the contract was silent there, and silence lets a
regeneration get worse as easily as better.

## Mutation testing, two passes

`scripts/mutant_two_pass.sh <config.sh>` runs mutant against the ORIGINAL
implementation twice, once per oracle, selecting the spec file with
`--integration-argument`, then dumps every surviving mutant per subject
with `mutant session subject` into `<oracle>_alive.txt` and prints a
per-subject table. mutant is licensed; the usage flag is the human's call.

```bash
bundle exec mutant run --usage <opensource|commercial> --integration rspec \
  --integration-argument spec/.../component_contract_spec.rb -j 4 \
  -- 'Namespace::Component*'
bundle exec mutant session list
bundle exec mutant session subject --session-id=<id> 'Namespace::Component.method'
```

First-run numbers, 583 mutations over 10 subjects:

| Oracle | Examples | Killed | Alive | Coverage |
|---|---|---|---|---|
| Original spec | 39 | 513 | 70 | 88.0% |
| Contract spec | 24 | 523 | 60 | 89.7% |

Report per subject, not only the total. A subject can regress while the
aggregate improves; in the first run the contract lost ground on exactly
one subject, the one holding the unpinned decision.

## Classifying survivors

Sort every survivor by hand. It is the highest-value reading in the
protocol, and it is the calibration set if you later use a judge.

| Class | What it looks like | Action |
|---|---|---|
| Equivalent | `.to_i` on an Integer, a namespace alias inside its own module, `.*` to `.+` on a regex that only ever sees one form, a guard already applied one call earlier | None |
| Log-only | Any rewrite or deletion of a log call | If the intent promises a log at a level, assert it. One assertion per promised call turns a promise into an evaluation. 24 of 60 in the first run. |
| Dead code | A whole guard removed and nothing notices because a later decision subsumed it | Compaction candidate. Remove the code; mark the earlier record `superseded_by` the later one. Five survivors proved the cap-to-window clamp dead since the quarter-window bound. |
| Evaluation gap | Real behavior changes and no example in either oracle reaches it | Add the assertion to the contract now, before regenerating. Seven survivors in the first run traced to one gap (an output line of zero on a degenerate window); two more to a collaborator fallback untested through the query methods. |
| Deliberate decision hole | The exact value of a margin, ceiling, or divisor changes and every property still holds | Legitimate by design. Record which decisions are unpinned and rely on the behavioral diff for them. `raw / 4` to `raw / 5` in the first run. |

Three cheap additions (assert the log, assert no output key without a
window key, run the consistency example with the collaborator fallback)
would have taken the first run's contract from 89.7% to roughly 95%,
leaving the equivalents, the deliberate holes, and the dead code that
compaction removes.

## What "better" means here

Expect candidates to be equivalent on realistic inputs and marginally
better on degenerate ones, with fewer lines and comments that carry
reasons instead of incident narrative. Say both in the findings. That is a
real drop in conceptual weight and a null change in behavior, and it does
not by itself justify swapping the code in.
