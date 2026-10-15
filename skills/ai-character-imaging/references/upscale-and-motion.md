# Upscale, patch and motion

## Upscale
- Skip it if native resolution already covers the largest render (check the
  site's decoded ratio, not the file size).
- Topaz (High Fidelity V2, on fal) with **face enhancement off**. On, it
  repaints the face waxy and slightly off-model.
- Real-ESRGAN invents hair strands and plastic skin. Avoid for faces.
- Always compare at 100% crop against the original before replacing it.

## Patch, don't regenerate
An image edit to remove a logo or fix a hand also re-renders the face a little.
Take only the fixed region: `patch_merge.py` feathers a mask around it and
reports the mean difference outside the patch (should be ~0).

## Motion loops
- Kling v3 image-to-video (4K, on fal). The approved still is the first frame
  and the poster, so the page never flashes a different face.
- Close the loop: Kling first+last-frame mode with the same still at both ends,
  or cut at the best matching pair (`loop_seam.py`). Crossfades ghost; avoid.
- Pick loops from raw clips, never from finished masters with burned-in text.
- Prompt small motion: breathing, hair in wind, a blink, a slow head turn.
  Large motion drifts the face by second 3.
- Seedance refused real-looking faces; Veo returned empty results. Have a fallback.
- Encode web loops muted, H.264 + an AV1/HEVC alternative, with the poster.
