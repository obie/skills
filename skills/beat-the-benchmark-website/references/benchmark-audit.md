# Benchmark audit

Do this before any design or build decision, and again at every review
round. Open the benchmark in a real browser (Playwright is fine) at the same
widths you will test your own site at. Fetch-and-summarise tools miss
layout, motion and phone behaviour.

## 1. Inventory the areas

List every area the benchmark has, plus every area your site will have.
A typical showcase site:

| Area | What to look at |
|---|---|
| Home fold (desktop) | Scale of the hero, type hierarchy, what the first screen lets you do |
| Home fold (phone) | Is the subject's face or product visible? Is the primary action above the fold? |
| Home below the fold | Section rhythm, transitions, density |
| Motion | Hero loops, scroll moments, signature type effects, reduced-motion handling |
| Navigation | Desktop nav, phone menu, language switch, focus trap |
| Detail pages (films, products, projects) | Hero, player, stats, galleries, filters, search |
| Per-item pages (single image, single product) | Image beside tools? Download, copy, prev/next, deep link back |
| Records / making-of | Spec strip, chapters, costs, notes, section index |
| Docs / wiki | Search, grouping, TOC, read time, related, evidence |
| Agent surfaces | llms.txt, JSON API, MCP tools and prompts, skill download |
| Typography | One coherent system? Consistent title styles across cards? |
| 404, footer, social links | Often forgotten, often where "pixel perfect" fails |
| Performance | Lighthouse mobile, LCP, CLS, weight |

## 2. Write the rubric

For each area, write one line on what the benchmark does well, as a
technique you can match or beat ("type laid over a full-bleed face",
"archive filters with live counts"), not as code to copy. Never copy the
benchmark's code or assets.

## 3. Verdict per area

Rate each area **Below**, **Meets** or **Exceeds**, with a reason tied to
what you saw. Rules:

- One overall impression is not a verdict. Only per-area verdicts count.
- "Exceeds" needs a concrete advantage (for example: the image and its
  tools fit one desktop screen, where the benchmark's image page spends the
  phone fold on black space).
- Areas the benchmark lacks (a music section, bilingual pages) can only
  Meet or Exceed. Say so explicitly rather than inventing a comparison.
- Re-run the comparison every round. Areas move: a home hero went from
  Below to Meets once it became poster-scale with type over the image.

## 4. What usually separates Below from Meets

From the case study, in the order they showed up:

1. Phone first screen without the subject's face or the primary action.
2. A framed card hero where the benchmark goes full-bleed with type on top.
3. Thin per-item pages (no download, no prev/next, slug as the title).
4. Docs without search, grouping or TOC; text-only articles.
5. Discography or catalogue that doesn't let people actually listen or buy.
6. Process claims without inspectable evidence (link the inputs).

## 5. What does not close the gap

More decoration, more animation, smaller type, or a wholesale redesign.
Independent reviewers said this repeatedly. Fix the named journeys.
