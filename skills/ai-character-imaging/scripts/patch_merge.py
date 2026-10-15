#!/usr/bin/env python3
"""Merge a feathered rectangle of an edited image back into the original.

usage: patch_merge.py original.png edited.png x,y,w,h out.png [--feather 24]
Requires Pillow and numpy. Prints the mean absolute difference outside the
patch, which should be ~0: proof the rest of the frame (the face) is untouched.
"""
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

p = argparse.ArgumentParser()
p.add_argument("original"); p.add_argument("edited"); p.add_argument("box"); p.add_argument("out")
p.add_argument("--feather", type=int, default=24)
a = p.parse_args()

orig = Image.open(a.original).convert("RGB")
edit = Image.open(a.edited).convert("RGB")
if edit.size != orig.size:
    edit = edit.resize(orig.size, Image.LANCZOS)
x, y, w, h = map(int, a.box.split(","))

mask = Image.new("L", orig.size, 0)
ImageDraw.Draw(mask).rectangle([x, y, x + w, y + h], fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(a.feather))
out = Image.composite(edit, orig, mask)
out.save(a.out)

m = np.asarray(mask) == 0
diff = np.abs(np.asarray(out, dtype=np.int16) - np.asarray(orig, dtype=np.int16)).mean(axis=2)
print(f"outside-patch mean diff: {diff[m].mean():.4f} (should be ~0)")
print(f"inside-patch mean diff:  {diff[~m].mean():.2f}")
