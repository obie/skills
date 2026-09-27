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
#                     e.g. "ContextWindowEnv*"
#   MUTANT_USAGE      mutant --usage flag value, e.g. "commercial"
#   CONTRACT_SPEC     spec path (relative to PROJECT_ROOT)
#   ORIGINAL_SPEC     spec path (relative to PROJECT_ROOT)
#   OUT_DIR           absolute path to write logs into (e.g. <experiment>/mutation)
#   MUTANT_YML        optional: path to the .mutant.yml this run should use
#                     for the preflight check below; defaults to
#                     PROJECT_ROOT/.mutant.yml.
#
# Output: <OUT_DIR>/original_spec.log, <OUT_DIR>/contract_spec.log, and a
# one-line summary of killed/alive/coverage per pass on stdout. Full
# surviving-mutant diffs are mutant's own `mutant session subject` output;
# re-run mutant interactively against the alive list for that, this script
# only produces the summary logs.
#
# Before either pass runs, this script checks .mutant.yml for the
# oracle-validity settings a DB-backed subject needs (see
# ../references/scoring.md, "Oracle-validity gotchas"): a timeout counts as
# a kill by default, and concurrent workers against a shared test database
# deadlock, which also counts as a kill. Both produce a fake-looking pass.
# The check is a grep, not a YAML parse, so it can be fooled by unusual
# formatting — read the printed warnings, don't just trust the exit code.

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

check_mutant_yml() {
  local yml="${MUTANT_YML:-$PROJECT_ROOT/.mutant.yml}"
  if [ ! -f "$yml" ]; then
    echo "WARNING: no .mutant.yml found at $yml — a DB-backed subject needs" >&2
    echo "  mutation.timeout >= 60.0, coverage_criteria.timeout: false, and" >&2
    echo "  jobs: 1, or timeouts/deadlocks will be counted as kills. See" >&2
    echo "  references/scoring.md, 'Oracle-validity gotchas.'" >&2
    return
  fi

  local timeout jobs cov_timeout
  timeout=$(grep -E "^\s*timeout:\s*[0-9.]+" "$yml" | head -1 | grep -Eo "[0-9.]+")
  jobs=$(grep -E "^\s*jobs:\s*[0-9]+" "$yml" | head -1 | grep -Eo "[0-9]+")
  cov_timeout=$(grep -A2 "^\s*coverage_criteria:" "$yml" | grep -E "^\s*timeout:\s*(true|false)" | head -1 | grep -Eo "true|false")

  if [ -z "$jobs" ] || [ "$jobs" != "1" ]; then
    echo "WARNING: $yml does not set 'jobs: 1' — forked workers sharing one" >&2
    echo "  test database can deadlock, and mutant counts a deadlock as a kill." >&2
  fi
  if [ -z "$timeout" ] || (( $(echo "$timeout < 60" | bc -l 2>/dev/null || echo 1) )); then
    echo "WARNING: $yml does not set mutation.timeout >= 60.0 — a slow" >&2
    echo "  DB-backed spec can time out under mutation, and mutant counts a" >&2
    echo "  timeout as a kill by default." >&2
  fi
  if [ -z "$cov_timeout" ] || [ "$cov_timeout" != "false" ]; then
    echo "WARNING: $yml does not set coverage_criteria.timeout: false — a" >&2
    echo "  timed-out mutation scores as covered no matter the timeout budget." >&2
  fi
}
check_mutant_yml

run_pass() {
  local name=$1 spec=$2
  local log="$OUT_DIR/${name}.log"
  echo "== mutant pass: $name (oracle: $spec)"
  bundle exec mutant run \
    --usage "$MUTANT_USAGE" \
    --integration rspec \
    --integration-argument "$spec" \
    -- "$MUTANT_SUBJECT" 2>&1 | tee "$log" | tail -20
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
