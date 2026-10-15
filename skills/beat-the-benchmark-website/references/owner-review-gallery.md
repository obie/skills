# Owner review gallery

Owners give better feedback with a thumb and a sentence per item than with
a paragraph in chat. Whenever you need the owner to choose between
candidates (hero images, plates, looks, covers, layouts), publish a voting
gallery instead of asking.

## Shape

- One page, sections per round, newest round on top. Older rounds stay
  below with their votes, so the owner can compare.
- Each tile: the image (tap to enlarge), its id, 👍 and 👎 toggles, and a
  notes box. Wide images get wide tiles.
- Votes save automatically to a store you can read back (for example a
  claude.ai artifact with the `db` capability, read with ArtifactData), so
  you never re-ask in chat.
- Downscale images for the gallery (about 1400–1600px long edge, JPEG q80).
  Keep originals elsewhere.

## Reading the votes

- Read every round's votes and notes before generating the next round.
- Notes are often the real signal: "too old", "too fat", "not her",
  "looks very AI generated", "love this one". Turn each into a concrete
  change in the brief.
- An approved item with a critical note ("good but looks AI generated") is
  a direction, not a pick.
- When the owner later rejects things they approved earlier, the reference
  set is wrong, not the individual images. Fix the inputs.

## Running rounds

1. Generate 2–3 candidates per slot.
2. Publish or update the gallery; tell the owner what to look for.
3. Read votes; write the next brief from the notes.
4. When a pick is clear ("there she is!"), promote it to canon and use it
   as the first reference for everything after.
