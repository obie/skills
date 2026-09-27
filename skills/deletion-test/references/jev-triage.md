# Judging survivors with a calibrated decision model

Optional step 9. Sorting mutation survivors by hand is the highest-value
reading in the protocol and the reason teams abandon mutation testing at
scale. A calibrated decision model can do the sort as a filter: it never
replaces the deterministic gates, and it never decides which assertion to
add. Chapter 5 allows a model judge only for questions a deterministic
check cannot answer, and only calibrated against human-scored examples.
The hand labels from step 6 are that calibration set.

Piloted with the lead's `feelings` gem over `ruby_decision_model`, which
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

## Second run

Sixty survivors were `ContextWindowEnv`, above. A second
module, `ContextOverflowGuard`, gave 51 contract-spec
survivors and ran both follow-ups from the first run: whole-module context
and a 0.8 confidence gate, same judge (`typesafe/jev-1.13`), same three-way
question plus noul.

Hand labels after the five-to-three collapse (`evaluation_gap` folds into
`behavior_change`; `dead_code`, `deliberate_hole`, and `equivalent` all
fold into `equivalent`): 16 equivalent, 0 log-only, 35 behavior-change.

|  | Whole-module context | Method-only context |
|---|---|---|
| Overall agreement | 37/51 = 72.5% | 41/51 = 80.4% |
| False negatives (real gap called equivalent) | 5 | 1 |
| High-confidence (≥0.8) subset | 21 | 21 |
| Agreement inside that subset | 16/21 = 76.2% | 15/21 = 71.4% |

Method-only won on both metrics that matter for a filter: fewer false
negatives and a smaller error count overall. Whole-module context did not
repeat the first run's pattern of helping; on this module it cost four
extra real gaps mislabeled equivalent, all in one family (early-return
rewrites inside a fallback method that fall through to the same
`unless_exist` write regardless of the branch, so a caller one method away
never sees a difference — exactly the kind of cross-method reasoning
whole-module context was supposed to supply, and here it supplied the
wrong answer instead). Every false negative in both contexts scored below
0.8, so the confidence gate caught its own errors: a human re-read a case
the judge had already flagged as uncertain, not a silently dropped gap.

The 0.8 rule, run as a routing policy (auto-close only `equivalent` at
confidence ≥ 0.8, route everything else to a human): whole-module
auto-closed 2 of 51, method-only auto-closed 1 of 51, and zero real gaps
landed in either auto-closed pile. Same as the first run, the rule is
safe; the yield is small on a pile this size (two mutants saved out of 51,
one out of 60 in the first run).

The noul question added nothing on this module: no mutant scored below
0.2 in either context, so a "dismiss below 0.2" rule never fires, and the
`[0.2, 0.8]` middle band held the great majority of mutants regardless.

Why the two modules disagreed on whether whole-module context helps: the
first module's equivalents were a cross-method value the judge could not
see without the calling method, so more context raised recall on those
without ever fixing the run's dominant failure family. The second
module's equivalents were cheap and local — alternate spellings of the
same check, a relation method with two equally valid names, a default
argument value, an early-return path whose both branches converge one line
later — and its evaluation gaps were guard removals and boundary shifts
visible entirely within the mutated method. Nothing elsewhere in that
module changes whether the local guard matters, so extra context only
diluted the signal. The two runs together say the deciding factor is
whether the module's own hard cases require tracing a value through a
second method; when they don't, whole-module context has no capability gap
to close and costs accuracy for free.

## Third run

`ContextWindowEnv` again, this time change-by-regeneration,
39 survivors of the third-round candidate (RC3) under the 35-example contract.
Both contexts run, same judge (`typesafe/jev-1.13-20260917`):

| Context | Agreement | Confidence ≥ 0.8 |
|---|---|---|
| method-only | 30/39 (76.9%) | 10/11 correct |
| whole-module | 32/39 (82.1%) | 17/17 correct |

Whole-module context won this run. Run 1 said whole-module helped; run 2
said method-only won on both metrics that matter for a filter. Three
runs, two of three favoring whole-module, on three different modules: the
answer is still "run both," not "pick one."

**The 0.8 dismissal gate held for the third time.** No real gap was
auto-closed in either context; every mutant the judge called `equivalent`
at 0.8 or higher was hand-labeled equivalent too.

**A taxonomy finding.** After the classifier agent's pass, the lead
relabeled three survivors `deliberate_hole`: a rounding-direction change
(`floor` to `ceil`) on a window value the contract deliberately never
pins, and two whitespace-trimming mutations on a promise the intent never
made. The judge called all three `behavior_change`, one at up to 0.9
confidence. The judge was right about the behavior, since those mutations do
change a result for some input, and wrong about the contract, which the
lead had established the module deliberately does not pin there. The
three-way question (`equivalent` / `log_only` / `behavior_change`) has no
way to express "yes, this changes behavior, and the contract is allowed
not to care about it." That is a real gap in the classifier, not a
mistake by the judge: it was answering the question it was asked
correctly.

Recommendation for the gem: either pass the intent's list of deliberate
decision holes to the judge as context before it answers, so it can rule
out a mutation of a deliberately-unpinned value the way a human reviewer
would, or add a fourth class, `deliberate_hole`, to the question itself
so the judge can say what it actually means instead of forcing
`behavior_change` on a decision the contract already excused.

## Using it

1. Hand-label first. Check the counts against your own arithmetic; a
   rule-based labeler and the lead's arithmetic disagreed by three in the
   first run and the labeler was right. The second run used a reviewed
   `labels.json` instead of the rule-based labeler (see the next step) —
   prefer that path once you've done the by-hand survivor review, since it
   is the more faithful record and doesn't carry this kind of discrepancy
   forward silently.
2. Run `parse_mutants.rb`, then `run_jev.rb`, then `analyze.rb` (see
   `scripts/README.md`). Adapt the hand-label rules block per module, or
   use `HAND_LABELS` to feed in a reviewed `labels.json` instead (see
   `scripts/README.md`).
3. Run both contexts (`WHOLE_MODULE_CONTEXT=0`, the default, and `=1` on
   `run_jev.rb`) before assuming either one is better on your module. The
   two runs above disagree on which context wins, and the deciding factor
   — whether the module's real evaluation gaps need cross-method
   reasoning to spot — is not something you can tell without running
   both.
4. Compare. Report the confusion matrix, agreement at confidence ≥ 0.8,
   and the count under 0.6. List every disagreement with your own verdict.
5. Trust the 0.8 confidence gate for dismissals; it has been safe (zero
   real gaps auto-closed) across both runs and both context settings, but
   expect it to save relatively little on a pile of about 50 survivors —
   two mutants in each run so far, not the bulk of the pile.
6. Do not expect whole-module context to help by default — `run_jev.rb`
   defaults to method-only context for this reason; opt into whole-module
   with `WHOLE_MODULE_CONTEXT=1` only after comparing both. It helps only
   when the module's equivalents require tracing a value into a different
   method; when a module's equivalents are local, syntactic variants
   reachable from the mutated method's own text, whole-module context adds
   noise and false negatives instead.
7. Keep the tape and the hand labels in the repo. They are the fixture for
   re-checking the judge when its model version moves.

## What it does not do

It does not write the contract assertion that closes a gap, does not
decide which record supersedes which, and does not author decision
records. It has no rationale to give; it has a probability. Those stay
lead work, and the judge only shortens the sorting that comes before them.
