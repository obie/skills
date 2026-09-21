# Findings template

Lead with the answer. A reader who sees only the first paragraph should
know whether the component survived deletion and what the code knew that
nothing else did.

```markdown
# Findings: deleting and regenerating `Namespace::Component`

Date. Branch. "Nothing here has merged."

## Headline
Did it survive? How many arms, what they were given, first-run results,
behavioral agreement out of N inputs, where the differences were and who
was right. Then the two or three things that surprised you.

## Results table
| | Contract spec | Original spec | Rubocop | Diffs vs original (of N) | Spec runs to green | Lines / comment lines |
| Original | | | | 0 | | |
| Arm A | | | | | | |
Pairwise diffs among candidates. Non-edge diffs per candidate (should be 0).

## 1. Where the candidates differ from the original
One subsection per input family. Say what the original does, what each
candidate does, what the contract asserted, and who is right. Each is an
evaluation gap whether or not the original was wrong.

## 2. Provenance that leaked
What the sparse arm found outside the module. Which neighbor restates the
numbers. Which record now carries the dependency.

## 3. What the intent was missing
Every question the regenerators asked. Every ambiguity they resolved alone.
Contradictions found. Which of these are answered in decisions.yml but not
in intent.md.

## 4. Variance between arms
Structural differences. Numerical differences. Where variance concentrated
(it should be where the oracle is silent). Comment density before and after.

## 5. Evidence with a shelf life
Any decision premise that live evidence no longer supports.

## 6. The old oracle
Did the original spec accept the candidates? What did it pin that the
contract does not, and the reverse?

## 7. Mutation testing
Table per oracle. What the contract kills that the original does not, and
why (one shape). What the original kills that the contract does not, and
whether that is deliberate. Survivor classification with counts. Dead
code proven. The three cheapest additions and the coverage they buy.

## 8. Compaction candidates
Dead rules. Duplicate namespaces or classes. Narrative in comments a record
now holds. Neighbors restating numbers.

## 9. What this cost
Lead judgment time versus regeneration time versus machine time.

## 10. What to land in the host project
Ordered PRs, smallest blast radius first: durable layer with the
additions; records moved to a home that travels with the app; comment
trims; compaction; docs page for the convention.

## 11. Next component
Pick one that breaks an assumption this run relied on.
```

## Judging "objectively better"

Expect the regenerated code to be equivalent on realistic inputs and
marginally better on degenerate ones, with fewer lines and comments that
carry reasons rather than narrative. That is a real reduction in
conceptual weight and a null change in behavior. Say both. Do not
recommend swapping the code in on that basis; recommend making the next
real change to the module a regeneration, and land the durable assets now.
