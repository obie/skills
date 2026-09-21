# Decision records

Version control says what changed. A decision record says why the system
became this way: the driver, what was rejected and why, the evidence, the
invariant the decision protects, who stood behind it, and the premises it
assumed (chapter 6). Records live in a file that travels with the
component, in YAML so they can be queried, and they are written as
structured data, never as a design doc that ages into fiction.

## What earns a record

A decision gets a record when at least one holds:

- It is expensive or dangerous to reverse: money, data integrity,
  security, a published contract.
- It would look arbitrary to a competent stranger: a magic number, a narrow
  limit, an unexplained synchronous call.
- It encodes a constraint another component or team quietly depends on.

Everything else stays in the diff. A record file full of noise is one
nobody reads.

## Shape

```yaml
- id: output-ceiling                # kebab-case, referenced from intent.md
  date: 2026-09-18
  version: v0.123.1
  decision: OUTPUT_CEILING = 32,000 bounds the output reservation for every model.
  driver: >
    Every reserved output token comes one-for-one off the provider's input
    wall. grok's catalog cap is 128,000; reserving all of it puts the wall
    at 372k. 32,000 is what CC already gives every Claude model.
  alternatives:
    - option: 64,000
      rejected: Would put grok's blocker at 369,400, below the ~395k largest session observed alive under the old wall.
    - option: 128,000 (the full cap)
      rejected: The wall drops under CC's guards; see reservation-before-margin.
  evidence: With 32,000 grok gets advertised 421,200, trigger 388,200, blocker 398,200, wall 468,000. Corey read 390-396k at death.
  invariant: I6, I7
  approved_by: Obie
  conditions:
    - Largest live grok session under the old wall was ~395k (ONE observation)
    - CC's Claude output budget is 32,000
    - grok's catalog cap is 128,000
  expires: "The 395k bound stops mattering once no session that grew under the old wall can still be alive. Reboot sweep finished 2026-09-18 19:40 UTC; a rollback would re-arm it."
  source: ["PR #1459", "Fizzy 3889"]   # quote anything containing "#" or ": "
```

Quote any value containing `#`, `: `, or starting with a backtick, and
parse the file after editing (`ruby -ryaml -e 'YAML.safe_load_file("<file>", permitted_classes: [Date])'`).
The first records written for this skill silently lost everything after a
`#` until they were parsed.

Optional fields: `kind` (`fact` for values read from a binary or vendor
doc, `cross-system` for a dependency another component holds,
`known-gap` for a documented limit), `held_open` for a reviewer concern
deferred at the time, `depends_on` (record ids), `superseded_by`, `notes`.

## Conditions and expiry

`conditions` are the premises. They are the most useful field, because a
record is dangerous exactly when it is confidently stale. When a premise
stops holding, the record is suspect and gets re-examined rather than
trusted. In the first run one premise ("grok's catalog cap is 128,000")
had expired within two days of the record being written; the live catalog
said 450,000. A standing check that re-reads the shapes named in
conditions is cheap. A calibrated judge can also be asked "does this
premise still hold" given the record and current evidence.

`expires` names the condition under which the record is known to stop
mattering. Time-bound decisions (a deploy-time safety bound) always have
one.

## Negative knowledge

The `alternatives` field is the most valuable and the most fragile part.
Working code only records what was kept. Write the rejected option and the
specific reason it lost, with the number that decided it where there was
one. In the first run the two rejected alternatives for one decision were
the two previous shipped versions of the same line, each of which had
caused an incident.

## Supersession

When a later decision makes an earlier one unreachable, do not delete the
earlier record. Add `superseded_by: <id>` and a note. Mutation testing
finds these: a survivor that deletes a whole guard and nothing notices is a
rule the code no longer needs, and the record explains why it once did.

## Where to start

Forward, never backward. You cannot retrofit a decade of lost reasoning.
Start at the component you would most hesitate to let an agent rewrite,
capture there as decisions happen, and attach capture to a review gate that
already exists ("why, and what did you reject?"). The deletion-test survey
step is a one-time backfill for one component, which is affordable because
the PRs and tickets still exist.

## Test for completeness

Imagine regenerating the component from scratch. For every constant in the
result that would look arbitrary to the reviewer, ask whether a record
explains it. The ones with no answer are the gaps, and they are exactly
what the next regeneration will throw away.
