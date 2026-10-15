---
name: beat-the-benchmark-website
description: "Build or overhaul a showcase, portfolio, artist, product or character website so it measurably meets or exceeds a named benchmark site, and prove it instead of claiming it. Runs a per-area benchmark audit, a single generated source of truth for every figure, an owner voting gallery for assets, parallel builds with one integrator, parallel independent QC and Codex adversarial review against immutable preview deployments, a scope freeze, and a parity-checked production ship ending in owner sign-off. Use when the user names a site to beat or match, asks for world-class or pixel-perfect fit and finish, says a launch looks off, or wants extensive desktop and phone testing before shipping."
---

# Beat the Benchmark Website

The owner names a site they admire and says "at least this good". This
skill turns that into a verdict you can defend: every area of the new site
rated **Below / Meets / Exceeds** against the same area of the benchmark,
by reviewers who did not build it, on the exact bytes that ship.

It exists because the obvious path fails. The first launch this skill was
distilled from shipped on Lighthouse 98, a clean link crawl and an agent's
"production-ready". The owner opened it and found overlapping stats, wrong
numbers, a blurry hero with the subject's face covered, and no playable
video. Reaching "0 Below" took ten QC rounds and seven adversarial reviews.
Nearly every defect was a process gap. Start here and you start at round ten.

## When to use

- The user names a benchmark site ("match claudia.gallery", "better than X").
- The brief says world-class, pixel-perfect, premium, or "test extensively on
  desktop and phone".
- A site already shipped and the owner says it looks off or is "a disaster".
- You are about to deploy and the only evidence is scores and agent reports.

## Roles

Run this as a team. Keep the lead (you) on strategy, rulings and review.

| Role | Owns | Never does |
|---|---|---|
| Lead | Rulings, scope, reading screenshots, deploys to production | Ships on a report it has not checked |
| Builder(s) | Disjoint files; one integrator does the single build | Deploys to production, commits without the lead |
| Imaging | Asset generation, upscales, video loops | Edits site code |
| QC | Full matrix, measurements, report with severities | Fixes anything |
| Codex | Independent adversarial review of the live preview | Edits source |
| Owner | Taste rulings, facts only they know, final sign-off | Has to repeat themselves (record rulings in memory) |

## The loop

1. **Audit the benchmark in a real browser.** Inventory every area (home
   fold, below the fold, detail pages, per-item pages, archive, docs, agent
   surfaces, 404, footer, motion, performance). Write what the benchmark
   does well in each, as techniques, not code. See
   `references/benchmark-audit.md`.
2. **Pin one source of truth.** Every figure on the site comes from one
   generated data module, produced by a script from the real source files,
   with the derivation commented. Pages, API, llms.txt, MCP tools and
   downloads all import it. Nothing is hand-typed into prose.
3. **Make assets with the owner in the loop.** Show candidates in a voting
   gallery (thumbs up/down plus a note per item, stored where you can read
   it back) instead of asking for verdicts in chat. See
   `references/owner-review-gallery.md`.
4. **Build in parallel, integrate once.** Builders own disjoint files and
   message before touching shared ones (i18n, global CSS, layout). One
   integrator builds and deploys to a **preview branch only**.
5. **Review the immutable deployment.** Point QC and Codex at the hashed
   preview URL (`<hash>.<project>.pages.dev`), never a dev server or a
   moving alias. Run them in parallel. See `references/qc-matrix.md` and
   `references/codex-review.md`.
6. **The lead looks.** Shoot full pages at a desktop and a phone width,
   tile them, and read the montages yourself before every ship. Agents miss
   things a human glance catches (a face covered by a sticker, a fake chart).
7. **Fix in one batch.** Fold QC findings, Codex findings and owner notes
   into one change set, one build, one new immutable preview, and a fast
   re-verify of only the changed items plus a smoke matrix.
8. **Scope freeze, then ship with parity.** When the owner needs it done,
   land only what is in flight, defer the rest explicitly. Deploy the exact
   verified `dist`, then diff production against the verified hash
   (`scripts/parity.sh`). Commit, push, then ask the owner to sign off.

## Non-negotiables (each one cost a round)

- **Look yourself.** Never ship on Lighthouse, crawls or "production-ready".
- **Every number traces to a source file.** If it does not reconcile, drop
  it. One film once showed three different clip counts on three pages.
- **No invented data.** No decorative charts, sample figures or
  placeholder metrics that read as real. A "polish" pass once drew a fake
  rising price line under a "Live chart" label next to a Buy button.
- **Freeze the build under review.** A rebuild mid-run voided a full QC
  round. QC only ever targets an immutable hash.
- **Measure sharpness from the decoded file.** Upscale = source pixels ÷
  (rendered CSS px × DPR). Fail above 1.15×. Values above 1 the other way
  (oversampling) are fine. Desktop can look perfect while phones are 4×
  stretched.
- **Phone is a first-class target.** Test 390×844 and 360×780 in WebKit
  with real DPR. Primary action above the fold; every tap target ≥44px.
- **The owner's taste rulings win.** Record them as overrules and pass them
  to reviewers so they stop re-raising them.
- **Check for other sessions before every deploy.** `git log`, `git status`
  and production itself. Another session once landed twenty commits and
  deployed mid-round.
- **No production deploy or push without the owner's go**, unless they
  explicitly delegated it for this task.

## Severity scale (shared by QC and Codex)

- **P0**: site broken or a core journey impossible.
- **P1**: blocks shipping: wrong facts, rights or integrity breach, a
  primary action missing on phone, an obvious visual defect in the first
  screen.
- **P2**: polish. Ships if the owner is waiting, gets logged and closed next.

SHIP means 0 P0 and 0 P1 on the immutable build, plus the lead's own look.

## References

- `references/benchmark-audit.md`: area inventory, Below/Meets/Exceeds rubric.
- `references/qc-matrix.md`: widths, engines, metrics, report template.
- `references/codex-review.md`: running Codex as an adversarial reviewer.
- `references/owner-review-gallery.md`: the voting-gallery pattern.
- `references/content-integrity.md`: quotes, leaks, provenance, money.
- `references/cloudflare-pages.md`: immutable previews, apex DNS, gotchas.
- `references/browser-gotchas.md`: WebKit, fonts, motion, embeds.
- `references/case-study.md`: the round-by-round story this came from.

## Scripts

Node scripts need `npm i playwright@1.60.0` in a scratch directory and
`npx playwright install chromium webkit`. See `scripts/README.md`.

- `shoot.mjs`: full-page screenshot matrix (widths × engines × URLs).
- `ratio.mjs`: decoded-file upscale ratio for every rendered image.
- `targets.mjs`: tap-target sizes and above-the-fold checks for selectors.
- `sweep.mjs`: forbidden-token and allow-list sweep over text and every attribute.
- `jsonld.mjs`: parses and summarises JSON-LD on every page.
- `parity.sh`: diffs production against a verified preview hash.
