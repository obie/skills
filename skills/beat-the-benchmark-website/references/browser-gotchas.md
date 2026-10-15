# Browser and front-end gotchas

Each of these cost at least one review round.

## WebKit

- **3D-transformed gradient grids** (`perspective` + `rotateX` on a
  repeating linear-gradient) rasterise as a flat diagonal hatch in WebKit
  while Chromium draws converging lines. Project the grid to an SVG at build
  time instead.
- **Scroll-driven animations inside `@media (prefers-reduced-motion:
  no-preference)`** can crash a WebKit tab when the preference changes while
  the page is open: the media query tears down live view timelines
  mid-recalc. Put the timelines under `@media all`, gate them with a class
  (`html.moving`), and make the preference handler idempotent and deferred
  with `requestAnimationFrame`.
- **Playwright WebKit and DPR.** WebKit ignores `deviceScaleFactor` unless
  the context has `isMobile: true`. Verify `window.devicePixelRatio` in the page.
- **Playwright version.** Newer Playwright WebKit builds may fail on older
  macOS ("Unknown setting: PushAPIEnabled", "frozen webkit"). Pin 1.60.0.

## Images

- `naturalWidth ÷ renderedWidth` reports every srcset image as about
  1/DPR. Measure the decoded candidate: the chosen srcset width divided by
  (rendered width × DPR).
- `sizes` must describe the drawn box, including `object-fit: cover`
  crops. A wide image in a tall cover box is drawn at height × aspect,
  wider than the column. Use `max(<column term>, <height> * <aspect>)`.
- Give hero images their source width in `srcset`; capping at 1280 made
  phone heroes 3.5× stretched.
- Art-direct phone heroes with `<picture>` and dedicated portrait sources
  rather than cropping 21:9 plates into a tall box.
- Preload only the first hero (`fetchpriority="high"`, media-split
  `imagesrcset`); defer later slides until after load.

## Type

- Font subsets can claim a glyph and draw it wrong (™ rendered as a
  quote mark). Exclude it with `unicode-range` so the system font draws it.
- Condensed display faces with accents (Ú) collide with the line above at
  tight leading. Measure clearance at every width.
- Avoid one-word last lines on taglines: `text-wrap: balance` plus a
  non-breaking space.
- One title style per grid. Mixed uppercase display and title-case body on
  sibling cards reads as a bug.

## Global CSS collisions

A global `nav { position: sticky; top: 0 }` silently applied to a table of
contents built as `<nav>` and covered the site header on phones. Scope
global element rules to the header, or reset them on components.

## Embeds and players

- Click-to-load facades for YouTube, Spotify and charts: no third-party
  requests before the click, a visible "Open on …" link that survives a
  blocked frame, and a keyboard-reachable close button.
- Esc can't close a player once focus is inside a cross-origin iframe; the
  iframe swallows the key. Provide the close button and accept it.
- Safari blocks autoplay with sound inside embeds; a second tap on the
  provider's own play button is expected.

## Copy buttons

`navigator.clipboard.writeText` can be denied. Use one shared helper with
localized success and failure messages in a `role="status"` region, and
select the text on failure. `data-copy-target` should accept ids with or
without `#`; one stray `#` once broke eleven buttons.

## Language switching

Use locale-independent section IDs, with alias anchors for old localized
hashes, so switching language keeps the reader's place.
