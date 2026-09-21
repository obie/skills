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
evaluation gap, deliberate decision hole. Fix the real gaps in the
contract spec now; record the deliberate holes in findings. mutant is a
licensed tool; confirm the usage flag with the human.

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
6 are the calibration set; record a tape.

### 10. Findings (lead writes)

Follow `references/findings-template.md`. Lead with the headline, then the
results table, then each gap with the input that exposed it.

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
