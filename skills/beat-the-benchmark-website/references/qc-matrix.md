# QC matrix

QC is a separate agent that never fixes anything. It reports, with evidence,
against an immutable preview URL.

## The matrix

| Dimension | Values |
|---|---|
| Widths | 1920, 1440, 1280, 1024, 768, 390×844, 360×780 |
| Engines | Chromium and WebKit (Playwright 1.60.0; newer builds may not run WebKit on older macOS) |
| Phones | `isMobile: true`, `deviceScaleFactor: 3` (WebKit ignores DPR without isMobile) |
| Languages | Every locale |
| Routes | Every sitemap URL plus a sample of per-item pages and the 404 |
| States | Default, reduced motion, keyboard only, menu open, embeds activated |

Scroll each page top to bottom before a full-page capture so lazy images and
reveal animations settle. CSS scroll-driven animations can still capture as
blank: emulate `prefers-reduced-motion: reduce` for the screenshot pass.

## Measurements (numbers, not impressions)

| Check | Pass |
|---|---|
| Horizontal overflow | `scrollWidth <= innerWidth` on every page and width |
| Console and network | 0 errors, 0 failed requests (except the intended 404) |
| Broken images | 0 (`complete && naturalWidth > 0` after scrolling) |
| Upscale ratio | source px ÷ (rendered px × DPR) ≤ 1.15 for every image (`scripts/ratio.mjs`) |
| Contrast | ≥ 4.5:1 for text, measured on real pixels where text sits over imagery |
| Tap targets | ≥ 44×44 CSS px; primary actions and follow links above the phone fold (`scripts/targets.mjs`) |
| CLS | 0 on key pages |
| Lighthouse mobile | Performance ≥ 95, Accessibility 100, Best practices 100 (preview SEO is low because of noindex; ignore that) |
| Engine parity | Chromium and WebKit page heights within ~200px; diff hero regions |
| Leaks and rights | `scripts/sweep.mjs` with the project's forbidden list and allow-list |
| Structured data | `scripts/jsonld.mjs`: parses everywhere, `sameAs` exact |

## Controls to exercise

Play and close the video player (including Esc and focus return), the phone
menu (focus trap, Escape, scroll restore), the language switch on deep
routes (keeps the `#hash`), gallery filters and search (counts match visible
tiles, empty state), copy buttons (success and clipboard-denied feedback),
click-to-load embeds (no third-party requests before click), lightbox focus
cycle, and reduced motion toggled mid-page.

## Look at the screenshots

Automated checks miss meaning. Tile the full-page shots into montages and
look: faces covered, the same pose twice on one page, a placeholder tag left
in, a duplicated wordmark, a fake chart. QC agents must open every flagged
crop themselves, and the lead looks at the key pages every round.

## Report template

```
# QC round N on <immutable URL>
Verdict: SHIP | NO-SHIP. Counts: P0 x · P1 y · P2 z.
## Blockers (P1+): id, page, width, engine, crop path, what's wrong, what fixed looks like
## Re-verified: prior ids → fixed / partial / open, with evidence
## Measurements: matrix size, overflow, errors, worst upscale, contrast min, Lighthouse
## Benchmark comparison: area → Below / Meets / Exceeds, one reason each
## Known and accepted: overrules from the owner, deferred items
```

Number findings by round (QC7-01, QC8-14) so later rounds can close them by id.
