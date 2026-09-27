# deletion-test scripts

Mechanical helpers for the protocol in `../SKILL.md`. Each is a template to
adapt per module under test, not a generic tool to run unmodified — read
the file before running it.

## scripts/ (baseline, mutation, scoring — steps 5, 6, 8)

- **`dump.rb`** — Step 5 (Baseline). Stubs the module's dependency,
  enumerates its public methods, builds a grid of synthetic shapes, real
  shapes fetched once from the live source, edge values (zero, negative,
  string, float, raising, nil), and collaborator/decoration variants; runs
  the grid against the original to produce `baseline.json`. Adapt the
  method list and shape grid per module. Input: the module source and its
  dependency. Output: `baseline.json`.
- **`shapes.rb`** — the synthetic-shape and edge-value definitions used by
  `dump.rb` (and by each arm's own dump run in Step 8), factored out so
  both baseline and candidate dumps build the grid identically. Input:
  none (pure data/generator). Output: consumed by `dump.rb`, not run
  standalone.
- **`run_baseline_wrapper.rb`** — wraps `dump.rb` in one outer transaction
  that is always rolled back, so a dump run leaves the database untouched.
  Needed because a probe that creates records under a uniqueness
  constraint (e.g. a fixed name) would otherwise leave those rows behind
  after the first dump, and every dump run after that — the baseline's and
  every arm's — would fail on the same constraint. Run it in place of
  `dump.rb` directly, for the baseline dump as well as every candidate's:
  `$RUNNER_CMD run_baseline_wrapper.rb <probe.rb> <impl_path> <out.json>
  <path/to/dump.rb>`. `score.sh` already does this for candidate dumps.
- **`mutant_two_pass.sh`** — Step 6 (Mutation, two passes). Runs `mutant`
  against the original once per oracle (contract spec, then original
  spec) and dumps every survivor per subject to a text report per pass.
  Input: the module source, the contract spec, the original spec, a
  `mutant` license. Output: two alive-mutant reports (e.g.
  `mutation/contract_spec_alive.txt`, `mutation/original_spec_alive.txt`).
- **`score.sh`** — Step 8 (Score). Run once per arm (`score.sh <arm>`):
  copies a candidate implementation into place, runs the contract spec,
  the original spec, rubocop, and `dump.rb`, diffs the candidate's dump
  against `baseline.json`, then restores the original file (it traps
  exit — never run two scores in parallel, they'd swap the same file).
  Input: `candidates/<arm>/` file plus `baseline.json`. Output: per-arm
  score summary and dump diff under `candidates/<arm>/`.
- **`pairwise_diff.py`** — Step 8 (Score), after all arms are scored.
  Diffs every pair of candidate dumps and the baseline dump input-by-input
  to find any input where any two runs disagree. Input: each arm's dump
  output plus `baseline.json`. Output: a diff report naming every
  differing input, for hand review.

## Change-by-regeneration templates (not part of this skill's scripts/)

The third run (`ContextWindowEnv`, changing an
existing component rather than deleting and rebuilding it; see the
change-by-regeneration section of `../SKILL.md`) produced two scripts
worth adapting per module. Both live in the experiment directory
(the experiment directory's `scoring/` folder),
not in this skill, because they're specific to one component's shapes;
treat them as templates to copy and edit, the same way `dump.rb` and
`score.sh` here are templates.

- **`expected_diff.py`**: compares a candidate's dump against the
  baseline using a whitelist instead of unconditional equality: a set of
  input shapes allowed to differ once a real change is in flight, and the
  exact expected new value at each. Prints every differing key with both
  values, then `EXPECTED-DIFF: exact` or `EXPECTED-DIFF: MISMATCH` with
  every offending key named (unexpected diff, missing expected diff, or a
  whitelisted key with the wrong value).
- **`collect_and_score.sh`**: the per-arm driver for a change-by-
  regeneration round: copies an arm's regenerated file and notes out of
  its worktree, runs `score.sh` for that arm, then runs `expected_diff.py`
  against the dump it produced and tees the verdict to
  `candidates/<arm>/expected_diff.txt`. One arm at a time, same
  swap-and-restore caution as `score.sh`.

## scripts/jev/ (optional Step 9 — see `../references/jev-triage.md`)

Sorts mutation survivors from Step 6 into the same three buckets a human
would use, with a calibrated judge (the lead's `feelings` gem over
`ruby_decision_model`), and checks the judge's labels against the hand
labels you already produced doing Step 6 by hand. Skip this whole
directory unless you already have `feelings`/`ruby_decision_model`
available — see `../references/jev-triage.md` for when it's worth using.

Both gems are published on RubyGems (`feelings`, `ruby_decision_model`).
Live (non-replay) runs require `OPENROUTER_API_KEY` or `TYPESAFE_API_KEY`
in the environment.

Run order:

1. **`parse_mutants.rb`** — parses the Step 6 alive-mutants report (e.g.
   `mutation/contract_spec_alive.txt`), extracts each mutated method's
   original source from the module file, applies a hand label to each
   survivor, and writes `mutants.json` next to itself. The method scanner
   matches `def name` and `def self.name` alike.
   - Inputs (env vars): `EXPERIMENT_DIR`, `MODULE_SOURCE`,
     `MODULE_NAMESPACE`; optional `ALIVE_REPORT` (path to the alive report,
     absolute or relative to `EXPERIMENT_DIR`; defaults to
     `mutation/contract_spec_alive.txt`) and `METHOD_NAME_PATTERN`.
   - Output: `scripts/jev/mutants.json`.
   - Two classification modes, chosen by whether `HAND_LABELS` is set:
     - **`HAND_LABELS=<path to labels.json>`** — reads hand labels from a
       file instead of the rule block. `labels.json` is an array of
       `{"mutant_id": "<hash>", "label": "<label>"}` objects, one per
       surviving mutant, with label one of `equivalent`, `log_only`,
       `dead_code`, `evaluation_gap`, `deliberate_hole` (the five classes
       from `../references/scoring.md`). The script collapses these onto
       the judge's three: `evaluation_gap` becomes `behavior_change`;
       `dead_code` and `deliberate_hole` both become `equivalent`, since
       both mean no realistic input distinguishes the mutant. A mutant
       with no entry in the file aborts the run rather than defaulting
       silently. Use this mode once you've already done the by-hand
       survivor review from Step 6 and written it down as `labels.json` —
       it's the more faithful path, since the rule block only ever
       approximates that review.
     - **Unset (default)** — falls back to the rule-based `classify`
       block inside the script (the `# === ADAPT:` comment marks it);
       rewrite that block per module as before.
   - `MODULE_PURPOSE_FILE` (below, for `run_jev.rb`) is worth writing once
     and reusing across a two-context run: run `run_jev.rb` once with
     `WHOLE_MODULE_CONTEXT=0` or unset (the judge sees only the mutated
     method — this is the default) and once with `WHOLE_MODULE_CONTEXT=1`
     (the judge sees the whole module), on the same `mutants.json` and
     hand labels. Keep both `jev_triage.json` outputs — rename each
     immediately after the run (`jev_triage_whole_module.json`,
     `jev_triage_method_only.json`) since the next run overwrites the
     default name. Whether whole-module context helps is module-dependent
     (see `../references/jev-triage.md`, "Second run") — running both is
     the only way to know for a given module.
2. **`run_jev.rb`** — sends each mutant in `mutants.json` to Jev (one
   `most_like` choice among `equivalent` / `log_only` / `behavior_change`,
   plus one `like` noul for "changes observable behavior for some
   realistic input"), records a tape, and writes results.
   - Inputs (env vars): `EXPERIMENT_DIR`, `MODULE_NAMESPACE`, and
     `MODULE_PURPOSE` or `MODULE_PURPOSE_FILE` (a paragraph describing the
     module's purpose and public surface — no default, must be supplied);
     optional `WHOLE_MODULE_CONTEXT` (default off, method-only context;
     `=1` gives the judge the whole module's source instead — see the
     two-context recipe above).
   - Reads: `scripts/jev/mutants.json`.
   - Outputs: `$EXPERIMENT_DIR/mutation/jev_tape.json` (replayable tape),
     `$EXPERIMENT_DIR/mutation/jev_triage.json` (raw per-mutant results).
   - `--replay` reruns from the saved tape with no network call.
3. **`analyze.rb`** — prints the summary numbers, confusion matrix, and
   calibration tables from the saved results.
   - Input (env var): `EXPERIMENT_DIR`.
   - Reads: `$EXPERIMENT_DIR/mutation/jev_triage.json`.
   - Output: stdout only (paste into `mutation/README.md` or
     `findings.md` by hand).
- **`Gemfile`** — `feelings` + `ruby_decision_model` from RubyGems;
  set `FEELINGS_GEM_PATH` / `RUBY_DECISION_MODEL_GEM_PATH` to develop
  against local checkouts.

### Example run (live, calls the judge)

```bash
cd /path/to/skills/deletion-test/scripts/jev
export EXPERIMENT_DIR=/path/to/experiment-dir
export MODULE_SOURCE=/path/to/app/services/foo/bar.rb
export MODULE_NAMESPACE=Foo::Bar
export MODULE_PURPOSE_FILE=/path/to/experiment-dir/intent.md   # or MODULE_PURPOSE inline

ruby parse_mutants.rb          # regenerate mutants.json if the alive report changed
bundle exec ruby run_jev.rb
ruby analyze.rb
```

### Example run (replay, no network)

```bash
cd /path/to/skills/deletion-test/scripts/jev
export EXPERIMENT_DIR=/path/to/experiment-dir
bundle exec ruby run_jev.rb --replay
ruby analyze.rb
```

Outputs land in `$EXPERIMENT_DIR/mutation/`: `jev_tape.json` (the
replayable tape), `jev_triage.json` (raw per-mutant results). Write the
narrative summary (confusion matrix, disagreements, what class the judge
is weakest on) into `mutation/README.md` or `findings.md` per the main
protocol.
