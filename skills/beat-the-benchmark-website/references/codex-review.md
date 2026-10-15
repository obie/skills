# Codex as adversarial reviewer

A second model that did not build the site finds what your own agents
rationalise away. Run it at every quality gate, in parallel with QC.

## Command

```bash
cd <repo> && codex exec -s danger-full-access --skip-git-repo-check \
  -o docs/codex/review-roundN-last.txt "$(cat prompt.md)" < /dev/null
```

- `< /dev/null` is required. Without it `codex exec` waits on
  "Reading additional input from stdin" forever.
- The default `workspace-write` sandbox has no network, so Codex can only
  read source and old screenshots. For a live browser review, use
  `-s danger-full-access` (read-only review run) or
  `-c sandbox_workspace_write.network_access=true`.
- Run it in the background; a full live review takes 15–40 minutes.

## Prompt template

```
You are an adversarial design and engineering reviewer. Review the LIVE
preview <immutable URL> (source in site/) in a real browser (install
Playwright in /tmp; chromium AND webkit; 1440x900 and 390x844). Benchmark
it against <benchmark URL>, opened the same way. Bar: meet or EXCEED the
benchmark's fit and finish, world-class and pixel-perfect on desktop and phone.

Cover: <list of routes>. Previous reviews: <paths>; state which of their
issues are resolved.

Owner overrules, do not re-raise: <list>.

Write <report path> with: (1) per-area verdict Below / Meets / Exceeds with
reasons; (2) defects ranked P0/P1/P2 with exact fixes; (3) overall verdict.
Do not edit any source files.
```

## Handling the report

- Read the per-area table and the overall verdict first.
- Codex is usually right about honesty and journeys (fake data, labels that
  promise content a section doesn't deliver, dead button shapes) and about
  missing evidence. Fix those exactly as specified.
- Codex will keep flagging owner-approved taste decisions. Overrule them
  once, record the overrule, and pass the list in the next prompt.
- Check its evidence limits. A source-only review can't see motion or a
  loop that plays, so don't treat "Below" on motion from a source-only run
  as final.
- Expect "Meets" overall, not "Exceeds". An honest reviewer rarely gives a
  whole-site Exceeds; "0 Below" with named Exceeds areas is the realistic bar.
