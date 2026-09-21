#!/usr/bin/env python3
"""Pairwise behavioral diff across every deletion-test candidate + baseline.

Usage: pairwise_diff.py baseline.json candidates/A/dump.json candidates/B/dump.json [...]

Each argument after the first is a candidate's dump.json (same shape as
produced by scripts/dump.rb: {input_key: {method: result, ...}, ...}). The
first argument is always the original implementation's dump ("baseline").

Prints, for every pair including each candidate vs. baseline: how many of
the shared input keys differ. Then prints, for every input key that
differs in ANY pair, a compact table of what each source returned there --
this is what step 8 calls "read every differing input by hand" made
readable in one place instead of N separate two-way diffs.
"""
import json
import sys
from itertools import combinations


def load(path):
    with open(path) as f:
        return json.load(f)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1

    baseline_path = argv[1]
    candidate_paths = argv[2:]

    sources = {"baseline": load(baseline_path)}
    for path in candidate_paths:
        name = path.split("/")[-2] if "/" in path else path
        sources[name] = load(path)

    names = list(sources.keys())
    all_keys = set()
    for data in sources.values():
        all_keys |= set(data.keys())

    print(f"{len(names)} sources, {len(all_keys)} distinct input keys\n")

    diffing_keys = set()
    print("== pairwise diff counts")
    for a, b in combinations(names, 2):
        da, db = sources[a], sources[b]
        shared = set(da.keys()) & set(db.keys())
        diffs = [k for k in shared if da[k] != db.get(k)]
        diffing_keys |= set(diffs)
        print(f"  {a} vs {b}: {len(diffs)} of {len(shared)} shared inputs differ")

    if not diffing_keys:
        print("\nNo input differs across any pair. Full agreement.")
        return 0

    print(f"\n== {len(diffing_keys)} input(s) that differ in at least one pair")
    for key in sorted(diffing_keys):
        print(f"\n- {key}")
        for name in names:
            val = sources[name].get(key, "<missing>")
            print(f"    {name}: {json.dumps(val)}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
