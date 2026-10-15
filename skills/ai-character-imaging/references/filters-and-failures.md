# Filters and failures

| Symptom | Fix |
|---|---|
| Edit refused by content filter | Crop refs to head and shoulders; add "tasteful, high/modest neckline"; remove words about body. |
| Same pose as the ref in every output | Crop refs tighter; name a pose and "hands away from face". |
| Face drifts across a batch (Grok, Midjourney) | Switch to GPT Image edit with refs; put the newest approved pick as ref #1. |
| Looks older / heavier than canon | Add apparent age and build to the identity paragraph; reject and regenerate, don't patch. |
| Waxy skin after upscale | Face enhancement off, or don't upscale. |
| Loop seam jumps or ghosts | First+last-frame mode, or re-cut with `loop_seam.py`; no crossfade. |
| Logo or text appears | Never rule in prompt; patch with `patch_merge.py`. |
| Video model refuses or returns nothing | Try the next model; log the refusal in prompts.jsonl. |
