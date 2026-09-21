# Judging survivors with a calibrated decision model

Optional step 9. Sorting mutation survivors by hand is the highest-value
reading in the protocol and the reason teams abandon mutation testing at
scale. A calibrated decision model can do the sort as a filter: it never
replaces the deterministic gates, and it never decides which assertion to
add. Chapter 5 allows a model judge only for questions a deterministic
check cannot answer, and only calibrated against human-scored examples.
The hand labels from step 6 are that calibration set.

Piloted with Obie's `feelings` gem over `ruby_decision_model`, which
speaks to the Jev decision model: typed questions answered with calibrated
probabilities, a maybe band, and record/replay tapes so a judged run is
reproducible without a network. Scripts in `scripts/jev/`.

## What the judge gets

For each surviving mutant, one value made of three parts: a one-paragraph
statement of the module's purpose and public surface, the original source
of the mutated method, and the diff. Two questions:

**A three-way choice** (`most_like`, capture the full pick: label,
confidence, distribution):

- `equivalent`: "the mutation cannot change any observable return value or
  emitted env of the module for any input the surrounding code can pass;
  the mutated expression evaluates identically, or the code path is
  unreachable or masked by another bound"
- `log_only`: "the mutation only changes, weakens, or removes a log
  message; every return value and emitted env is unchanged"
- `behavior_change`: "the mutation changes what the module returns or
  emits for at least one realistic input"

**A yes/no** (`like`, no block, capture the probability): "changes
observable behavior for some realistic input".

Wrap the run in `Feelings.record` and save the tape. `run_jev.rb --replay`
re-scores from the tape with no network call.

## First-run results

Sixty survivors, judge `typesafe/jev-1.13`, 21 seconds wall time for 120
questions. Hand labels: 25 equivalent, 24 log-only, 11 behavior-change.

| | judge: equivalent | judge: log-only | judge: behavior-change |
|---|---|---|---|
| hand: equivalent (25) | 4 | 0 | 21 |
| hand: log-only (24) | 0 | 24 | 0 |
| hand: behavior-change (11) | 0 | 0 | 11 |

Agreement 39 of 60. Every disagreement ran one way: an equivalent mutant
called a behavior change. The judge never dismissed a real gap, never
mislabeled a log rewrite, and every mutant it called equivalent was one.

Read as a classifier, 65%. Read as the filter a pipeline would use, the
number that matters is different. The two errors cost differently:
dismissing a real gap silently weakens the oracle, while sending an
equivalent mutant to a human costs a minute. On that question the judge's
dismissals were 100% safe and its review pile was 32 instead of 60, with
all 11 real gaps inside it.

## Where it failed, and why

Fifteen of the 21 misses were one family: mutations of a clamp that a
bound in a *different* method already dominated for every reachable
input. Deciding those are inert requires cross-method reasoning the judge
could not do from one method's source, and it was confidently wrong there
(0.87 to 0.96). Four more were guard rewrites masked by the same method's
rescue clause. The last five were cosmetic rewrites where confidence was
low (0.27 to 0.79), which is calibration working: it knew it did not know.

## Using it

1. Hand-label first. Check the counts against your own arithmetic; a
   rule-based labeler and the lead's arithmetic disagreed by three in the
   first run and the labeler was right.
2. Run `parse_mutants.rb`, then `run_jev.rb`, then `analyze.rb` (see
   `scripts/README.md`). Adapt the hand-label rules block per module.
3. Compare. Report the confusion matrix, agreement at confidence ≥ 0.8,
   and the count under 0.6. List every disagreement with your own verdict.
4. Auto-act only on high-confidence `equivalent` and `log_only`; route
   everything else, and everything under the maybe band, to a human.
5. Keep the tape and the hand labels in the repo. They are the fixture for
   re-checking the judge when its model version moves.

Two follow-ups worth running before trusting it further: give the judge
the whole module rather than the mutated method and re-score the same
questions, to learn whether the clamp family was a context failure or a
capability one; then set the maybe band at 0.8 and measure the pile again.

## What it does not do

It does not write the contract assertion that closes a gap, does not
decide which record supersedes which, and does not author decision
records. It has no rationale to give; it has a probability. Those stay
lead work, and the judge only shortens the sorting that comes before them.
