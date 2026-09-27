---
name: deletion-test
description: "Run the regenerative-software deletion test on one component: extract its intent and decision records from code, history, and tickets; write a durable contract spec that asserts promises rather than pinned numbers; mutation-test both oracles; delete the implementation and regenerate it in isolated arms from the intent alone; score every candidate by behavioral diff; write findings that name evaluation gaps, leaked provenance, dead decisions, and compaction candidates. Use when asked to run the deletion test, regenerate a module from its spec, make a component replaceable, extract the reasons buried in a legacy file, or find out whether a test suite is a real oracle. Ruby/Rails tooling, framework-agnostic method."
---

# Deletion Test

Could we delete this component and rebuild it from what the system holds
outside the code? Chad Fowler's *Regenerative Software* makes that the
defining test of a replaceable component (chapter 2) and names what has to
survive deletion: intent, the architecture code compiles into, evaluations,
provenance, pace, deletion discipline, compaction (chapter 3). This skill
runs the test for real on one component and reports what the code knew
that nothing else did.

The result is never a swapped-in implementation. The result is the durable
assets extracted along the way, the list of promises the test suite was
silently not making, and a decision about whether the component is now
replaceable. First run on a 286-line Rails service: three independent
regenerations passed on the first try, the property contract beat the
original spec under mutation testing, and the code turned out to carry
one dead rule, one expired premise, and two latent edge defects.

## When to use this skill

- Someone asks to run the deletion test, regenerate a module from spec, or
  make a component safely replaceable.
- A module has dense incident history and its reasons live only in
  comments, commit messages, or tickets.
- You need to know whether a spec is an oracle or a museum of the current
  implementation.
- Before adopting regeneration tooling anywhere, to get a baseline on a
  real component.

Do not use it where the specification is the hard part (a novel algorithm,
a proof), where correctness must be proven rather than tested, or on a
component too small and stable to earn the machinery (chapter 11). Pick a
leaf with a clear boundary, few callers, existing behavior-level specs, and
the most incident history per line you can find. The easy first case is a
pure function whose reasons are already in comments. The informative second
case is a module whose reasons live only in git and tickets.

## What you produce

    <experiment-dir>/
      README.md            protocol as run, with the question it answers
      intent.md            scope, environment facts, surface, invariants, decisions
      intent-sparse.md     decisions withheld, for the sparse arm
      decisions.yml        one record per constraint a stranger would call arbitrary
      scoring/             dump.rb, score.sh, shapes.json, baseline.json
      mutation/            two mutant logs, alive lists, classification README
      candidates/<arm>/    regenerated file, regenerator notes, scores, diff
      findings.md          results table, gaps, leaks, variance, compaction list
    <app>/spec/.../<module>_contract_spec.rb   the durable evaluations

Plus, in the host project, the things worth landing: the contract spec,
the decision records in a home that travels with the app, comment trims
that point at records instead of restating numbers, and compaction PRs.
The branch itself exists to be read, never merged as a whole.

## Protocol

Judgment steps stay with the lead model. Mechanical steps go to cheaper
agents. Each step names which.

### 0. Pick and branch

Confirm callers with a grep for the constant name across app and lib,
count spec examples, read `git log --format='%h %ad %s' --date=short` for
the file. Create a branch named `experiment/regenerate-<module>`. Nothing
on it commits until the human says so.

### 1. Survey (delegate, read-only)

One agent maps the seams: subsystem layout, callers, spec mechanics, and
where the book's primitives already half-exist (audit trails, contract
tests, pace or risk labels, generated-code markers, architectural rules in
CLAUDE.md). A second agent builds the decision log: every PR that touched
the file, every ticket those PRs cite, `git log -p --follow`, written as a
dated chronology with driver, decision, evidence, rejected alternatives,
source. Ask for facts, forbid editorializing.

### 2. Intent (lead writes)

Follow `references/intent-template.md`. Scope, environment facts the code
compiles into, the public surface, invariants each with scope, what must
stay true, and why, then the decisions table, known limits. Every reason
links to a decision id. Include the derivation behind each decision, not
only its value; every regenerator in the first run asked for exactly that.
Produce the sparse variant by stripping the decisions section and grepping
the result for every decision value and id.

When the subject has side effects, the intent also needs: the order of
every pair of side effects that could go either way, with the reason;
every persisted shape pinned exactly (payload keys, summary text, which
boot or version a row is stamped with, what a prompt must say, not "as
before" or "same as the comment"); a positive example backing any stated
exclusion, never just an absence; expired premises stated as expired
rather than silently dropped, so a regenerator reproduces current behavior
instead of independently discovering and "fixing" it; and known races
named as known limits rather than left for a regenerator to paper over
with a guess.

### 3. Decision records (lead writes)

Follow `references/decision-record.md`. One record per constraint that is
expensive to reverse, would look arbitrary to a competent stranger, or
crosses a boundary. Record conditions and expiry. Mark facts (read from a
binary, a vendor doc) as `kind: fact` and cross-system dependencies as
`kind: cross-system`.

### 4. Contract spec (lead writes)

Follow `references/contract-spec.md`. Properties over grids, never pinned
numbers; the membership test is whether reimplementing in another language
would invalidate the assertion. Run it against the original; it must be
green. Write down which decisions it deliberately does not pin.

Never build a fixture with exactly one of everything (one owner, one
scope, one row on one boot); add a second of whatever there is only one of,
so a mutant that widens a query or a delete to touch every row of that
kind fails an example. Constrain every collaborator stub's arguments
(`with(...)`); an unconstrained stub lets a mutant pass it `nil` and
survive. Treat a stub on a class method as a design smell before you write
it, because it is a call-shape assertion rather than a behavior assertion, and prefer
stubbing the instance or letting the real collaborator (the database, for
a uniqueness check) produce the condition itself. Read every regenerator's
notes from step 7 as a review of the contract, not only of the intent: a
question or an unexpected pass often means the contract, not the arm, is
wrong.

### 5. Baseline

Write a probe file for `scripts/dump.rb` (its header documents the shape):
stub the dependency, enumerate public methods, build a grid of synthetic
shapes, real shapes fetched once from the live source with
`scripts/shapes.rb`, edge values (zero, negative, string, float, raising,
nil), and collaborator and decoration variants. Run it against the
original to get `baseline.json`. Check the raise count is zero. Put the
paths in a `config.sh` that the scoring scripts read.

### 6. Mutation, two passes

`scripts/mutant_two_pass.sh <config.sh>` runs mutant against the original
once per oracle and dumps every survivor per subject. Classify survivors with the
table in `references/scoring.md`: equivalent, log-only, dead code,
evaluation gap, deliberate decision hole, timeout artifact (a mutation that
loops forever under a neutered deadline check, counted alive only because
`coverage_criteria.timeout` is off; not a gap if the contract already
asserts the budget). Fix the real gaps in the contract spec now; record
the deliberate holes in findings. mutant is a licensed tool; confirm the
usage flag with the human. Before trusting a pass, check the
oracle-validity gotchas in `references/scoring.md` (timeout-as-kill,
deadlock-as-kill). If a cheaper model classifies survivors in bulk,
verify every high-signal label against the code and the contract yourself
before adding an example on its say-so; the fourth run's classifier
labeled 299 survivors evaluation gaps and about ten were real.

### 7. Regeneration arms (delegate, isolated)

Create one worktree per arm from HEAD. Worktrees carry only committed
files, so copy in the contract spec and the intent, copy `master.key` if
Rails needs it, verify the contract spec runs there against the original,
then delete the implementation and its original spec. Give each arm the
brief in `references/regenerator-brief.md`. Two arms get the full intent,
one gets the sparse intent. Run them in parallel on a cheap model. They
run the contract spec and rubocop themselves, capped at six attempts, and
write notes on ambiguities, choices, and questions.

### 8. Score

Copy each arm's file and notes into `candidates/<arm>/`, remove the
worktrees, then run `scripts/score.sh <config.sh> <arm>` one arm at a
time: contract spec, original spec, rubocop, dump, diff against baseline. Then
`scripts/pairwise_diff.py` across all candidates and the baseline. Read
every differing input by hand.

### 9. Judge survivors (optional, delegate)

`references/jev-triage.md`: a calibrated decision model sorts mutation
survivors as a filter beside the deterministic gates. Hand labels from step
6 are the calibration set; record a tape. Run it in both context settings
(`WHOLE_MODULE_CONTEXT=1` and `=0`, see `scripts/README.md`) before
concluding whole-module context helps or hurts on this module.

### 10. Findings (lead writes)

Follow `references/findings-template.md`. Lead with the headline, then the
results table, then each gap with the input that exposed it.

## Changing a component by regeneration

Once the durable layer exists, the same method can drive a real change
request, not only a deletion-and-rebuild. Run:

a. **Edit the intent, records, and contract first.** State the change in
   the durable assets before touching code: revise the invariants and
   decisions the change actually affects, supersede the record it
   invalidates, add the record it needs, and broaden or un-pend the
   contract examples the change is about.
b. **Run the contract against the unchanged module.** The exact red is the
   change request. "32 examples, 3 failures, exactly the three new ones"
   is a precise, checkable statement of what changed, and every arm can
   verify it before starting.
c. **Regenerate in isolated arms from the revised intent.** Two cheap arms
   plus one stronger-model arm, same isolation as the deletion test. Add
   one or two conventional-edit arms as a control: give them the original
   code, the original spec, and the card text as well as everything the
   regeneration arms get, and tell them to make the change by editing.
   Each round after the first uses fresh agents on fresh or reset
   worktrees, with no memory of the previous round's code or notes; move
   the previous round's notes somewhere the new round can't read them. A
   round's result is a statement about the current intent's sufficiency,
   not about whether an agent remembers being corrected.
d. **Score every candidate against the contract, the old oracle, lint, and
   the dump grid**, plus an "expected diff" checker that names exactly
   which input shapes are allowed to differ from the baseline and what
   their new values must be. `scoring/expected_diff.py` in the third run
   (see the experiment directory this skill's `references/scoring.md`
   points at) is the template: a whitelist of shapes, the exact expected
   value at each, and a verdict of `exact` or `MISMATCH`.
e. **Read every regenerator's notes and turn every question into an intent
   sentence.** Re-revise the intent, regenerate again, until a round
   converges (every candidate agrees with the others and the expected
   values on every grid input) and the notes stop asking questions. Report
   the never-seen retired oracle's failure count per round as a trend, not
   a single number. It should fall each round as the intent absorbs what
   used to live only in the old spec (fourth run: 20/20/19, then 18/16/16,
   then 16/15/13) even though the retired oracle is never the target and
   stays coupled to implementation details the arms never match exactly.
f. **Mutant the winner and triage survivors**, same as step 6 of the base
   protocol.
g. **Ship through the normal review path.** Treat a finding from an
   outside model or reviewer as another intent revision plus a
   regeneration, never a hand edit of the shipped candidate.

### Reading the third run

`ContextWindowEnv`, changing a two-decision clamp
and a zero-output silence. Four rounds, twelve candidates. Every
regeneration was green on its first spec run, in 1.5 to 4 minutes. Round 1
diverged from the expected result on 25 of 633 grid inputs, from two
intent silences (a query-method inconsistency with no known window, and
whether a Float catalog value counts as an integer). Round 2, from a
revised intent, converged: every candidate agreed on all 633 inputs.
Round 3's candidate had a read-order bug (it read the completion cap
before the window, changing what a mid-call catalog failure produced)
that the grid of stable inputs could not see and an outside adversarial
read (Codex) could. Round 4 shipped at 171 lines against the original's
236, with mutant scoring 459 of 491 (93.5%) against the contract.

### Reading the fourth run

The reboot family of `Supervisor`: eight public
methods, about 340 lines inside a 1,700-line class, that stop a daemon's
child process, claim a database row with a conditional update, write audit
rows, enqueue jobs, and mint a replacement boot. The first side-effecting
subject and the first region carved out of a larger class rather than a
whole file. Three rounds, nine candidates. Round 1 (105-example contract)
diverged from the original on 57, 57 and 41 of 175 recorded interaction
scenarios, every divergence one of two orderings or one persisted shape.
Revision 2 stated all of them; round 2 diverged on zero for all three
arms. Round 3 added the one behavior only the retired implementation spec
had held (an audit-insert retry on a unique-index collision) and diverged
on zero for two arms and on 24 for the third, which applied an
operator-stop rule to a method the intent explicitly excludes: a stated
invariant with no example behind it. Mutation testing of the original
with the 105-example contract killed 85.4% of 1,296 mutations against
81.4% for the 68-example implementation spec it retires; survivor
triage found ten real gaps, all one smell (a fixture with exactly one of
everything, or a stub that accepted any argument), and eleven survivors
that were mutations looping forever under the timeout policy, not gaps.

## Side-effecting subjects: the probe becomes an interaction recorder

A dump grid records return values over inputs, and that says nothing about
a method whose behavior is a sequence of writes and calls to other objects.
When the family under test claims rows, writes audit trails, enqueues
jobs, or calls a daemon protocol, replace the probe with an interaction
recorder.

- **What it records, per scenario.** The ordered collaborator calls with
  their arguments, the subject row before and after (ids normalized
  relative to the scenario's own row, since database sequences advance
  even inside a rolled-back transaction), the events written through
  model callbacks, the jobs enqueued, and the method's result or the
  exception it raised.
- **How it stays deterministic.** Script a fake harness rather than the
  real one: a scripted probe, a scripted stop acknowledgement, a scripted
  start outcome, a scripted operator action landing mid-window. Freeze
  the clock and turn `sleep` into `travel(1.second)` so a wait loop that
  compares `Time.current` to a deadline terminates with no real waiting.
  Collapse consecutive identical probe answers so the poll interval never
  enters the trace. Run every scenario inside a transaction and roll it
  back. Never fake anything inside the region under test itself; fake
  only at the collaborator seam the intent names, or a candidate that
  inlines the faked method bypasses the fake and runs its real timeout.
  Watch for a framework default that hides effects from the recorder (a
  job adapter that defers enqueue to commit sees nothing inside a
  rolled-back transaction; record at the enqueue call instead of the
  adapter). Keep an ordered create/destroy log for anything that can be
  written and then destroyed inside one call, since a before-and-after
  snapshot can't see it.
- **The recorder is an evaluation and gets the same review as the
  contract.** Two fidelity bugs in the fourth run surfaced only as false
  divergences a human then read: a classifier that matched the original's
  exact prompt wording instead of the intent's content terms, so a
  candidate's differently-worded but correct prompt scored as wrong; and
  a simulated operator Stop that flipped one column where the real one
  writes two in the same call, making a harmless asymmetry look like a
  bug. Fix the recorder, re-baseline against the original, and re-score
  every arm before concluding anything from a divergence.

## Carving a region inside a class

Not every subject worth regenerating is a file. When the family funnels
through a method that also serves other responsibilities of a large class,
there is no seam to extract without a production refactor first, and the
unit under test is a region: a marked slice of one class.

- **Delete in place, with a marker comment**, rather than lifting the
  region into its own file. The comment names what was here and points at
  the intent.
- **Declare the rest of the class as collaborators**, methods the
  regenerator may call but does not rebuild: the shared entry point that
  also handles first boots, session lookup, the history renderer, any
  outbound call the region shares with code outside it.
- **Split the implementation spec in two.** The examples that exercise the
  region become the never-seen scoring oracle. Everything else stays as
  the environment the region compiles into, and gets run against every
  candidate to confirm nothing outside the region broke. Check the split
  is clean by running the trimmed environment spec against the deleted
  region: any example that still calls into the region belongs to the
  oracle, not the environment, and moved out is evidence the region is
  real.
- **Give the arm the rest of the class as a legitimate input**, not
  something to avoid. Tell it plainly that comments elsewhere in the class
  are environment, not spec: a neighboring method's doc comment describing
  when the region's effects happen is a decision the intent may have
  dropped, and an arm that relies on it must report doing so.

## Hard rules

Each of these came from something that went wrong or nearly did.

1. **Regenerators never see the old code, the old spec, or git history.**
   Say so in the brief, forbid git entirely, and accept that isolation is
   by instruction. Ask them to report any violation instead of hiding it.
2. **Expect provenance to leak from neighbors.** A caller's comment that
   restates the module's numbers is a de facto contract. The sparse arm
   will find it. Record the leak as a finding and fix the neighbor.
3. **Durable evaluations assert promises, not decisions.** A margin, a
   ceiling, a divisor are compilation constraints, recorded with reasons.
   Name the ones the contract leaves unpinned; the numeric diff is the gate
   for those, and a regeneration that changes one passes the contract.
4. **Intent carries derivations.** "raw/4 because the blocker stays
   positive for any window above 7k" is intent. "raw/4" is a number.
5. **Grep the sparse intent** for every decision value and id after
   generating it. Multi-line references survive naive stripping.
6. **Restore the original after every score.** The scorer traps exit; do
   not run two scores in parallel, they swap the same file.
7. **Count your hand labels.** A rule-based labeler and an arithmetic slip
   disagreed by three in the first run; the labeler was right.
8. **Degenerate inputs are where the oracle is silent.** Include zero,
   one, and two as raw sizes, floats and strings where integers are
   expected, and a raising dependency. That is where every candidate
   differed from the original, and the original was wrong each time.
9. **Never swap the regenerated code in because you can.** Replacement is
   a means to cheap change. Land the durable assets; make the next real
   change to the module a regeneration.
10. **The intent needs a canonical home in the app before the second
    change.** A dated experiment directory is not where the next change
    will look for it. This repo keeps it at
    `decisions/<area>/<component>.intent.md`, beside the decision records
    it cites.
11. **"Numeric" is not a type rule.** Say Integer, and say what happens to
    everything else, for every source of the value. A regenerator turns
    an unstated type rule into a coin flip, and different arms will flip
    it differently.
12. **Read order of independent reads is a decision, not an implementation
    detail, whenever a partial failure is possible.** If the module reads
    two things from a collaborator that can fail between calls, the order
    determines which one survives a partial failure. State it and give
    the reason.
13. **A regenerator's "no behavior depends on this" is a claim to test,
    not a note to file.** Read it, and if a grid input can exercise the
    claim, add one.
14. **Publish every constant a caller reads, and let the contract assert
    it exists.** Grep the app for `Module::CONSTANT` before writing the
    public-surface section; an omission survives revision after revision
    otherwise, because every regenerator finds the call site and asks
    about it instead of failing on it.
15. **Every ordering of two side effects is a decision.** State which
    happens first and why, for any pair of writes or calls that could go
    either way. Regenerators pick the other order about half the time;
    the fourth run's round 1 diverged on exactly its unstated orderings
    and converged the moment they were stated.
16. **A stated exclusion needs a positive example, not just an absence.**
    Leaving one method out of a loop of examples encodes nothing. An arm
    that consolidates several methods into one shared tail will apply the
    tail's rule to all of them, pass every existing example while doing
    it, and only a contract example that pins the excluded method's own
    behavior catches it.
17. **A fixture with exactly one of everything is a mutation gap
    factory.** One profile, one scope, one boot's rows lets a mutant widen
    a `where` clause to claim every live row or delete every scope's cache
    and still pass. Add a second of whatever the fixture has only one of.
    Constrain every collaborator stub's arguments (`with(...)`, not a bare
    stub); an unconstrained stub lets a mutant pass it `nil`.
18. **A stub on a class method is a call-shape assertion in disguise.**
    Stubbing `Model.create!` at the class level forces every regenerator
    to build the row that exact way to pass the example. Intercept at the
    instance, or let the database itself raise the condition (a real
    racer row inserted at the computed slot, for a unique-index
    collision) so any way of building the row is covered.
19. **Fresh arms every round, nothing carried over.** When an intent
    revision triggers another regeneration round, use fresh agents (or
    reset worktrees) with no memory of the previous round's notes or
    code, and rename the previous round's notes out of the new round's
    reach. A candidate that remembers the earlier feedback is testing
    whether the intent is now sufficient on its own, not whether an agent
    can follow a hint.

## What counts as a finding

- An input where a candidate and the original differ. Decide who is right;
  either way the contract was silent there.
- A survivor class in the mutation report that maps to a missing promise.
- A decision whose premise no longer holds in live evidence.
- A constraint the regenerators asked about that the intent answered only
  by value.
- Dead code proven by a survivor that removed it.
- Two names for one idea across namespaces; narrative in comments that a
  record now holds; a neighbor restating numbers.
- The cost split: hours of lead judgment versus minutes of regeneration.

## Reading the first run

Contract 24 examples, original 39. Three Sonnet arms: all green on the
first attempt, all passed the unseen original spec, 478 of 490 behavioral
inputs identical, 12 differences all on degenerate inputs the original
mishandled. Mutant on the original: 513 of 583 killed by the original spec,
523 by the contract. Two deliberate survivors (a divisor unpinned), five
proving a rule dead since a later bound subsumed it. The sparse arm
reverse-solved the withheld ceiling from a comment in a caller. A decision
premise about a vendor's catalog had expired within two days. Roughly ninety
minutes of lead judgment, about ten minutes per arm.
