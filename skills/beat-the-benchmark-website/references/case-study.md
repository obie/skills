# Case study: saindra.gallery vs claudia.gallery

saindra.gallery is the bilingual home of an open character: three music
videos, a discography, a wiki, a character reference, an MCP server and a
skill download. The owner's brief was "meet or exceed the fit and finish of
claudia.gallery… world class and pixel perfect… test extensively on desktop
and phone". Built with Astro on Cloudflare Pages by a lead plus builder,
imaging, QC and Codex agents, over two days.

## How the rounds went

| Round | What happened | Lesson |
|---|---|---|
| Launch 1 | Shipped on Lighthouse 98 and a link crawl. Owner: "a DISASTER". Overlapping stats, wrong numbers, a blurry frame with the face covered, no video. | Look yourself. Scores are not QC. |
| QC v1 | 62 defects (12 P0). Phone heroes 3.7–4.2× upscaled; a 900px frame stretched full-bleed five times. | Measure decoded upscale on phones. |
| v2–v4 | Facts in new prose wrong (2:50 vs 2:49, 14 vs 13 clips, a cost chain that didn't sum). | One generated figures module; no hand-typed numbers. |
| Mid-run | A builder rebuilt `dist` while QC was shooting; Chromium jobs died, round voided. | Review immutable preview hashes only. |
| Redesign | Another session landed 20 commits and deployed while this team was mid-round. | Check git and production before every deploy. |
| Codex r3 | "Below overall": the phone Play button cut off, per-image tools under the fold, docs without structure, a discography you couldn't listen from. | Benchmark journeys, not looks. |
| Owner | "the discography has no click through links", "the coin note is apologetic". | Owner priorities trump the rubric; make them prominent. |
| QC v8–v9 | Lyric translations and glosses hidden in `aria-label`s; an 8px-wide social link. | Sweep every attribute; measure every target. |
| Codex r6 | A polish pass had drawn a fake rising chart under "Live chart". | No invented data, ever. |
| QC v10 / Codex r7 | 0 Below, 12 Meets, 7 Exceeds; Codex "Meets" overall. Owner signed off. | Realistic finish line: 0 Below, named Exceeds. |

## What moved areas from Below to Meets or Exceeds

- Home hero: framed card on cream → poster-scale video loop to the edge,
  display type as the loudest element, face first on phones.
- Per-image pages: image beside a rail with title, download, copy prompt,
  prev/next and a deep link back into the gallery; descriptive captions
  instead of slugs.
- Docs: grouped index, full-text search with synonyms, TOCs, read times,
  related articles, real before/after evidence with linked inputs.
- Records: early spec strip, section index, reconciled costs.
- Music: listen links on every release, a prominent listen section on the
  home page, real covers.

## Cost of getting it wrong

Roughly ten QC rounds, seven Codex reviews and a day of rework after the
first launch. Following the loop in SKILL.md from the start would have
caught every launch-1 defect before the owner saw it.
