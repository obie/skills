#!/usr/bin/env bash
# Usage: scripts/score.sh <config.sh> <arm>
#
# Orchestrates one deletion-test regeneration arm's full scoring pass:
# swaps the candidate implementation into the real tree, runs the contract
# spec, runs the original (never-seen-by-the-arm) spec as an "would the
# old oracle have accepted this" check, runs a linter, runs the behavioral
# dump against the baseline, diffs it, and restores the original file no
# matter what happens (trap on EXIT) so a scoring run can never leave the
# tree mutated.
#
# <config.sh> is a small shell file, specific to the component under test,
# that sets these variables before this script runs its steps:
#
#   PROJECT_ROOT      absolute path to the app root (cd here to run specs)
#   RUBY_BIN_DIR      optional: prepended to PATH (e.g. an asdf/mise ruby bin dir)
#   IMPL_PATH         absolute path to the real implementation file this
#                     experiment temporarily overwrites and restores
#   CANDIDATES_DIR    absolute path to the dir containing <arm>/<impl-basename>
#   CONTRACT_SPEC     spec path (relative to PROJECT_ROOT) for the durable
#                     contract/property spec
#   ORIGINAL_SPEC     spec path (relative to PROJECT_ROOT) for the original
#                     implementation's pre-existing spec
#   RUNNER_CMD        command prefix for running Ruby scripts against the
#                     app's environment, e.g. "bin/rails runner"
#   DUMP_PROBE        absolute path to the probe.rb for scripts/dump.rb
#   DUMP_SCRIPT       absolute path to scripts/dump.rb (this dir, usually)
#   BASELINE_JSON     absolute path to the baseline dump.rb output (produce
#                     this once against the original implementation before
#                     scoring any arm)
#
# Example config.sh:
#
#   PROJECT_ROOT=/path/to/app
#   RUBY_BIN_DIR=$HOME/.local/share/mise/installs/ruby/4.0.5/bin
#   IMPL_PATH=$PROJECT_ROOT/app/services/openrouter/context_window_env.rb
#   CANDIDATES_DIR=/path/to/experiment/candidates
#   CONTRACT_SPEC=spec/services/openrouter/context_window_env_contract_spec.rb
#   ORIGINAL_SPEC=spec/services/openrouter/context_window_env_spec.rb
#   RUNNER_CMD="bin/rails runner"
#   DUMP_PROBE=/path/to/experiment/dump_probe.rb
#   DUMP_SCRIPT=/path/to/deletion-test/scripts/dump.rb
#   BASELINE_JSON=/path/to/experiment/baseline.json

set -u
CONFIG=${1:?usage: score.sh <config.sh> <arm>}
ARM=${2:?usage: score.sh <config.sh> <arm>}
# shellcheck source=/dev/null
source "$CONFIG"

: "${PROJECT_ROOT:?config.sh must set PROJECT_ROOT}"
: "${IMPL_PATH:?config.sh must set IMPL_PATH}"
: "${CANDIDATES_DIR:?config.sh must set CANDIDATES_DIR}"
: "${CONTRACT_SPEC:?config.sh must set CONTRACT_SPEC}"
: "${ORIGINAL_SPEC:?config.sh must set ORIGINAL_SPEC}"
: "${RUNNER_CMD:?config.sh must set RUNNER_CMD}"
: "${DUMP_PROBE:?config.sh must set DUMP_PROBE}"
: "${DUMP_SCRIPT:?config.sh must set DUMP_SCRIPT}"
: "${BASELINE_JSON:?config.sh must set BASELINE_JSON}"

[ -n "${RUBY_BIN_DIR:-}" ] && export PATH="$RUBY_BIN_DIR:$PATH"

IMPL_BASENAME=$(basename "$IMPL_PATH")
CAND="$CANDIDATES_DIR/$ARM/$IMPL_BASENAME"
OUT="$CANDIDATES_DIR/$ARM"
[ -f "$CAND" ] || { echo "no candidate at $CAND"; exit 1; }
mkdir -p "$OUT"

BACKUP=$(mktemp)
cp "$IMPL_PATH" "$BACKUP"
cp "$CAND" "$IMPL_PATH"
cd "$PROJECT_ROOT" || exit 1
trap 'cp "'"$BACKUP"'" "'"$IMPL_PATH"'"; rm -f "'"$BACKUP"'"; echo "[restored original]"' EXIT

echo "== contract spec"
bundle exec rspec "$CONTRACT_SPEC" --format json --out "$OUT/contract_spec.json" > /dev/null 2>&1
python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
s = d['summary']
print(f'{s[\"example_count\"]} examples, {s[\"failure_count\"]} failures')
for e in d['examples']:
    if e['status'] == 'failed':
        print('  FAIL', e['full_description'])
" "$OUT/contract_spec.json" | tee "$OUT/contract_result.txt"

echo "== original implementation spec (the old oracle)"
bundle exec rspec "$ORIGINAL_SPEC" --format json --out "$OUT/original_spec.json" > /dev/null 2>&1
python3 - "$OUT/original_spec.json" <<'PY' | tee "$OUT/original_spec_result.txt"
import json, sys
d = json.load(open(sys.argv[1]))
s = d["summary"]
print(f'{s["example_count"]} examples, {s["failure_count"]} failures')
for e in d["examples"]:
    if e["status"] == "failed":
        msg = e.get("exception", {}).get("message", "").strip().splitlines()
        print(f'  FAIL {e["full_description"]}\n       {msg[0] if msg else ""}')
PY

echo "== lint"
bundle exec rubocop "$IMPL_PATH" 2>&1 | tail -1

echo "== behavioral dump"
$RUNNER_CMD "$DUMP_SCRIPT" "$DUMP_PROBE" "$IMPL_PATH" "$OUT/dump.json" 2>&1 | tail -3

python3 - "$BASELINE_JSON" "$OUT/dump.json" <<'PY' | tee "$OUT/diff.txt"
import json, sys
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
diffs = [k for k in a if a[k] != b.get(k)]
print(f"{len(diffs)} of {len(a)} inputs differ from the original")
for k in diffs[:60]:
    print(f"- {k}\n    orig: {json.dumps(a[k])}\n    cand: {json.dumps(b.get(k))}")
if len(diffs) > 60:
    print(f"... {len(diffs) - 60} more")
PY
