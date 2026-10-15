#!/usr/bin/env python3
"""Find the best seamless-loop cut in a clip.

usage: loop_seam.py clip.mp4 [--fps 12] [--min-seconds 3] [--region x,y,w,h]
Extracts small grayscale frames with ffmpeg, then finds the (start, end) pair at
least --min-seconds apart with the smallest mean difference. --region weights
the comparison to a face box (in output-frame pixels at 256 wide).
Prints the ffmpeg command to cut it.
"""
import argparse
import subprocess
import numpy as np

p = argparse.ArgumentParser()
p.add_argument("clip"); p.add_argument("--fps", type=float, default=12)
p.add_argument("--min-seconds", type=float, default=3); p.add_argument("--region")
a = p.parse_args()

W = 256
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                        "stream=width,height", "-of", "csv=p=0", a.clip], capture_output=True, text=True, check=True)
sw, sh = map(int, probe.stdout.strip().split(",")[:2])
H = round(sh * W / sw / 2) * 2
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", a.clip, "-vf", f"fps={a.fps},scale={W}:{H},format=gray",
                      "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
frames = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
if a.region:
    x, y, w, h = map(int, a.region.split(","))
    frames = frames[:, y:y + h, x:x + w]

n = len(frames); gap = int(a.min_seconds * a.fps)
best = (float("inf"), 0, 0)
for i in range(n):
    for j in range(i + gap, n):
        d = np.abs(frames[i] - frames[j]).mean()
        if d < best[0]:
            best = (d, i, j)
d, i, j = best
if d == float("inf"):
    raise SystemExit("clip shorter than --min-seconds")
s, e = i / a.fps, j / a.fps
print(f"best seam: {s:.2f}s -> {e:.2f}s  mean diff {d:.2f} (lower is better; <3 is usually invisible)")
print(f'ffmpeg -ss {s:.3f} -to {e:.3f} -i "{a.clip}" -an -c:v libx264 -crf 18 -pix_fmt yuv420p loop.mp4')
