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

## scripts/jev/ (optional Step 9 — see `../references/jev-triage.md`)

Sorts mutation survivors from Step 6 into the same three buckets a human
would use, with a calibrated judge (Obie's `feelings` gem over
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
   original source from the module file, applies the rule-based hand
   label (see the `# === ADAPT:` block inside — this is the one part you
   must rewrite per module), and writes `mutants.json` next to itself.
   - Inputs (env vars): `EXPERIMENT_DIR`, `MODULE_SOURCE`,
     `MODULE_NAMESPACE`; optional `ALIVE_REPORT` (path to the alive report,
     absolute or relative to `EXPERIMENT_DIR`; defaults to
     `mutation/contract_spec_alive.txt`) and `METHOD_NAME_PATTERN`.
   - Output: `scripts/jev/mutants.json`.
2. **`run_jev.rb`** — sends each mutant in `mutants.json` to Jev (one
   `most_like` choice among `equivalent` / `log_only` / `behavior_change`,
   plus one `like` noul for "changes observable behavior for some
   realistic input"), records a tape, and writes results.
   - Inputs (env vars): `EXPERIMENT_DIR`, `MODULE_NAMESPACE`, and
     `MODULE_PURPOSE` or `MODULE_PURPOSE_FILE` (a paragraph describing the
     module's purpose and public surface — no default, must be supplied).
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
