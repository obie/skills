---
name: ai-character-imaging
description: Use when generating a consistent AI character or persona across many images and short motion loops — a virtual artist, mascot, brand persona or recurring character — and the face must stay the same person from plate to plate. Covers the canon identity pack, prompt slots, model choice, content-filter workarounds, owner review rounds, upscaling without waxy skin, seamless Kling motion loops, and patching logos or defects without drifting the face.
---

# AI Character Imaging

Keep one synthetic person recognisably the same across dozens of stills and
video loops. The face is the product; every step protects it.

## The loop

1. **Build the canon identity pack.** 3–6 reference images of the *current*
   face, plus one identity paragraph in words. See `references/identity-pack.md`.
2. **Prompt with slots.** `{identity}, wearing {wardrobe}, {setting}, {expression}, {camera}`.
   References carry identity only; wardrobe and setting come from the text.
3. **Generate with an edit-with-references model.** GPT Image 2.5 edit with refs
   holds the face best. Grok drifts across a batch. Midjourney needs omni-ref
   and still wanders. Generate 4–8 per slot.
4. **Review in rounds.** Put every candidate in a voting gallery for the owner
   (keep / maybe / reject + note). Promote each approved pick into the pack as
   ref #1. See `references/rounds-and-review.md`.
5. **Finish.** Upscale only when native resolution falls short, with face
   enhancement off. Patch defects by merging a feathered region, never by
   accepting a whole re-edited frame. See `references/upscale-and-motion.md`.
6. **Animate.** Image-to-video from the approved still (first frame = poster),
   then close the loop and score the seam with `scripts/loop_seam.py`.

## Never rules (make these config, check every frame)

- Face visible and on-model; no second person in frame unless asked.
- No logos, watermarks, text or brand marks.
- Age and body stay on the canon; reject "too old", "too heavy", "too young".
- Hands away from the face, unless the shot calls for it.

## Failures you will hit

See `references/filters-and-failures.md`: content-filter refusals, pose copying
from refs, identity drift, waxy upscales, ghosting loop seams, models that
refuse real-looking faces.

## Bookkeeping

- Append every generation to `prompts.jsonl`: model, prompt, refs, seed, cost, output path, verdict.
- Track spend per round; video and 4K upscales dominate.
- API keys come from the environment (`FAL_KEY`, `OPENAI_API_KEY`); never print or commit them.

## Scripts

| Script | Use |
|---|---|
| `scripts/patch_merge.py orig.png edited.png x,y,w,h out.png` | Merge only a feathered region of an edited frame back into the original; reports drift outside the patch. |
| `scripts/loop_seam.py clip.mp4` | Find the start/end frame pair with the smallest difference, for a seamless loop cut. |
