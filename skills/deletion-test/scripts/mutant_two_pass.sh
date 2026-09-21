#!/usr/bin/env bash
# Usage: scripts/mutant_two_pass.sh <config.sh>
#
# Runs mutant (or any mutation tool with a compatible CLI shape) against
# the ORIGINAL implementation twice: once scored by the original spec,
# once by the new durable contract spec. This is step 6 of the protocol —
# run it BEFORE any regeneration arm, to find out whether the contract
# spec you wrote is actually a strong oracle before spending agent-time
# judged against it.
#
# mutant is licensed for commercial use; confirm the usage flag with
# whoever holds the license before running this against anything but a
# personal/OSS project.
#
# <config.sh> sets, in addition to the variables score.sh needs:
#
#   PROJECT_ROOT      absolute path to the app root
#   RUBY_BIN_DIR      optional: prepended to PATH
#   MUTANT_SUBJECT    the mutant --include/subject match expression,
#                     e.g. "Openrouter::ContextWindowEnv*"
#   MUTANT_USAGE      mutant --usage flag value, e.g. "commercial"
#   CONTRACT_SPEC     spec path (relative to PROJECT_ROOT)
#   ORIGINAL_SPEC     spec path (relative to PROJECT_ROOT)
#   OUT_DIR           absolute path to write logs into (e.g. <experiment>/mutation)
#
# Output: <OUT_DIR>/original_spec.log, <OUT_DIR>/contract_spec.log, and a
# one-line summary of killed/alive/coverage per pass on stdout. Full
# surviving-mutant diffs are mutant's own `mutant session subject` output;
# re-run mutant interactively against the alive list for that, this script
# only produces the summary logs.

set -u
CONFIG=${1:?usage: mutant_two_pass.sh <config.sh>}
# shellcheck source=/dev/null
source "$CONFIG"

: "${PROJECT_ROOT:?config.sh must set PROJECT_ROOT}"
: "${MUTANT_SUBJECT:?config.sh must set MUTANT_SUBJECT}"
: "${MUTANT_USAGE:?config.sh must set MUTANT_USAGE}"
: "${CONTRACT_SPEC:?config.sh must set CONTRACT_SPEC}"
: "${ORIGINAL_SPEC:?config.sh must set ORIGINAL_SPEC}"
: "${OUT_DIR:?config.sh must set OUT_DIR}"

[ -n "${RUBY_BIN_DIR:-}" ] && export PATH="$RUBY_BIN_DIR:$PATH"
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT" || exit 1

run_pass() {
  local name=$1 spec=$2 log="$OUT_DIR/${name}.log"
  echo "== mutant pass: $name (oracle: $spec)"
  bundle exec mutant run \
    --usage "$MUTANT_USAGE" \
    --include "$MUTANT_SUBJECT" \
    --integration rspec \
    -- "$spec" 2>&1 | tee "$log" | tail -20
  echo "log: $log"
}

run_pass "original_spec" "$ORIGINAL_SPEC"
run_pass "contract_spec" "$CONTRACT_SPEC"

echo
echo "== summary (grep the two logs for the mutant coverage line if this misses your mutant version's format)"
for f in "$OUT_DIR/original_spec.log" "$OUT_DIR/contract_spec.log"; do
  echo "--- $f"
  grep -Ei "killed|alive|coverage|mutations" "$f" | tail -8
done
