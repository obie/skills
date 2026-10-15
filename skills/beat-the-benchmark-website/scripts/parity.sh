#!/usr/bin/env bash
# Diff production against the verified immutable preview, page by page.
# Retries for up to a minute while the edge catches up.
# Usage: parity.sh <production origin> <verified preview origin> <path> [<path> ...]
# Example: parity.sh https://example.com https://3f2a9c1d.example.pages.dev /es/ /en/ /es/about/
set -u
prod="$1"; verified="$2"; shift 2
[ $# -gt 0 ] || { echo "usage: parity.sh <prod> <verified> <path>..."; exit 1; }
for attempt in 1 2 3 4 5 6; do
  bad=0
  for p in "$@"; do
    if ! diff -q <(curl -s "$prod$p") <(curl -s "$verified$p") >/dev/null; then bad=1; echo "  differs: $p"; fi
  done
  if [ $bad -eq 0 ]; then echo "production == verified preview ($# paths, attempt $attempt)"; exit 0; fi
  echo "attempt $attempt: not yet identical, waiting 10s"; sleep 10
done
echo "PARITY FAILED: production does not match the verified build"; exit 1
