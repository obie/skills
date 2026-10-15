# Content integrity

A beautiful site that misstates a fact, leaks an internal note or quotes
lyrics it shouldn't is not finished. These checks run every round.

## Facts and figures

- Generate every figure from source files with a script. Keep one module
  (for example `data/figures.json` plus a typed wrapper) and import it
  everywhere: pages, prose (interpolated), API, llms.txt, MCP tools, skill
  downloads.
- Comment each derivation (which file, which field, what counts).
- Name the noun. "66 shots" and "68 clips" can both be right; "68 shots"
  is wrong. Split screens, retakes and generated-vs-used counts trip this.
- Costs: one definition (for example "finished jobs, list price") used
  everywhere, with the breakdown summing exactly to the total. If it can't
  reconcile from the files, show only the total.
- Unreleased work shows no figures until it's final. Rough-cut numbers change.
- Dates the owner gives you: record "source: owner, <date>" in the data file.
  Don't upgrade "release date" into "streaming date" without being told.

## No invented data

No sample charts, mock dashboards or placeholder numbers that a visitor
could read as real. An unloaded embed shows a designed, data-free state
("Chart not loaded" plus a load button), never a drawn curve.

## Quotes and rights

- If someone else owns text (lyrics, scripts), keep an explicit allow-list
  of the exact lines that may appear in written copy.
- Translations and glosses are quotes. So is text in `aria-label`, `alt`,
  `title`, meta tags, JSON-LD, llms.txt and API output. Sweep all of them.
- On-screen typography taken from the work itself, shown in its original
  language and hidden from screen readers (`aria-hidden` SVG), is a
  design treatment, not copy. Record that ruling.
- Paraphrase private direction from the owner. Never publish dated private
  quotes, and loosen close paraphrases too.

## Leaks

- Internal IDs, shot codes, model profile codes, file paths, voice IDs and
  vendor names the owner doesn't want public must never reach visible text,
  APIs, MCP output or downloadable bundles.
- Sanitise once at the data layer (a `publicX()` function), then add a
  build-time guard that fails the build if a forbidden pattern appears.
- Rename public files that look internal (`plate-B1.jpg`) to descriptive names.
- Run `scripts/sweep.mjs` across every page and the agent surfaces each round.

## Evidence and provenance

When a page claims a process ("we fixed X by changing Y"), link the inputs:
full-size references, the exact before/after wording quoted verbatim from
the generation log, and a record page. Say plainly what each comparison
does not prove. If provenance is ambiguous, leave that example out rather
than publish an unverified record.

## Money, tokens and endorsements

- If the owner wants a token, coin or product promoted, present it
  confidently and prominently, not apologetically.
- Use one canonical disclaimer string defined once and read everywhere
  (for example "Meme coin. Not financial advice. Can go to zero.").
- Attribution wording exactly as the owner states it. "By X" is not
  "created by X" when X received it by transfer.
- No static price or market-cap figures; they go stale and mislead. Link a
  live chart instead.

## Trademarks and third-party marks

Exempt only what the owner explicitly asked for (official cover art, social
icons, embeds, a GitHub link). Everything else, including logos inside
generated images, is a defect.
