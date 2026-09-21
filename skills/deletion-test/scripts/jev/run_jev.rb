#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Runs the surviving mutants (mutants.json, produced by parse_mutants.rb)
# through Jev via the `feelings` gem: one `most_like` choice among
# {equivalent, log_only, behavior_change} plus one `like` noul for "changes
# observable behavior for some realistic input", per mutant. Records a tape
# to $EXPERIMENT_DIR/mutation/jev_tape.json and writes per-mutant results to
# $EXPERIMENT_DIR/mutation/jev_triage.json.
#
# The `feelings` and `ruby_decision_model` gems are published on RubyGems
# (see Gemfile in this directory — swap the `path:` sources there for
# version constraints if you don't have local checkouts). This script also
# requires OPENROUTER_API_KEY or TYPESAFE_API_KEY to be set in the
# environment for live (non-replay) runs.
#
# Usage:
#   EXPERIMENT_DIR=/path/to/experiment \
#   MODULE_NAMESPACE=Foo::Bar \
#     bundle exec ruby run_jev.rb            # live run (calls the judge)
#   EXPERIMENT_DIR=/path/to/experiment \
#     bundle exec ruby run_jev.rb --replay   # replay from the saved tape
#
# Configuration (env vars):
#   EXPERIMENT_DIR    - deletion-test experiment directory (mutation/ output
#                         subdirectory lives here)
#   MODULE_NAMESPACE  - namespace prefix mutant subjects are reported under,
#                         e.g. "Foo::Bar", used only to label the mutated
#                         method in the prompt sent to the judge
#   MODULE_PURPOSE    - a short paragraph describing what the module is for
#                         and its public surface (see MODULE_PURPOSE below
#                         for the shape). May instead be supplied as a file
#                         via MODULE_PURPOSE_FILE.
#   MODULE_PURPOSE_FILE - path to a text file containing the purpose
#                         paragraph, alternative to MODULE_PURPOSE.

require "bundler/setup"
require "feelings"
require "json"
require "time"

EXP = ENV.fetch("EXPERIMENT_DIR") { abort "Set EXPERIMENT_DIR (deletion-test experiment dir)." }
NAMESPACE = ENV.fetch("MODULE_NAMESPACE", "")
MUTANTS_PATH = File.join(__dir__, "mutants.json")
TAPE_PATH = File.join(EXP, "mutation/jev_tape.json")
RESULTS_PATH = File.join(EXP, "mutation/jev_triage.json")

# The module-purpose paragraph told to the judge alongside each mutant's
# diff. Keep this in the same shape as the pilot: what the module is for,
# in one or two sentences, then its public surface (method names and what
# they return), then any notable error-handling behavior. Configure via
# MODULE_PURPOSE or MODULE_PURPOSE_FILE — there is no sane default, this
# must describe your module.
MODULE_PURPOSE =
  if ENV["MODULE_PURPOSE_FILE"]
    File.read(ENV["MODULE_PURPOSE_FILE"]).strip
  elsif ENV["MODULE_PURPOSE"]
    ENV["MODULE_PURPOSE"].strip
  else
    abort "Set MODULE_PURPOSE or MODULE_PURPOSE_FILE describing the module under test."
  end

# Keep these three label descriptions and the noul description verbatim —
# they were tuned against the calibration set in the pilot run and changing
# the wording changes the judge's behavior. Keep LABELS in sync with the
# three hand-labels parse_mutants.rb's `classify` method produces.
LABELS = {
  equivalent: "the mutation cannot change any observable return value or emitted env of the module for any input the surrounding code can pass; the mutated expression evaluates identically, or the code path is unreachable or masked by another bound",
  log_only: "the mutation only changes, weakens, or removes a log message; every return value and emitted env is unchanged",
  behavior_change: "the mutation changes what the module returns or emits for at least one realistic input"
}.freeze

NOUL_DESCRIPTION = "changes observable behavior for some realistic input"

def build_value(mutant)
  subject_label = NAMESPACE.empty? ? mutant["subject"] : "#{NAMESPACE}.#{mutant["subject"]}"

  <<~VALUE
    Module purpose:
    #{MODULE_PURPOSE}

    Original source of the mutated method (#{subject_label}):
    #{mutant["method_source"] || "(source not found for this subject)"}

    Mutant diff (unified diff against the method above):
    #{mutant["diff"]}
  VALUE
end

replay_mode = ARGV.include?("--replay")

mutants = JSON.parse(File.read(MUTANTS_PATH))
puts "Loaded #{mutants.size} mutants."

results = []
start = Time.now

run = lambda do
  mutants.each_with_index do |mutant, idx|
    value = build_value(mutant)
    about = Feelings(value)

    answers = about.like(
      most_like: LABELS,
      changes_behavior: NOUL_DESCRIPTION
    )

    pick = answers[:most_like]
    mood = answers[:changes_behavior]

    result = {
      id: mutant["id"],
      subject: mutant["subject"],
      hand_label: mutant["hand_label"],
      diff: mutant["diff"],
      changed: mutant["changed"],
      jev_label: pick&.label,
      jev_confidence: pick&.confidence,
      jev_probabilities: pick&.probabilities,
      jev_model: pick&.model,
      noul_probability: mood&.probability,
      noul_model: mood&.model
    }
    results << result
    warn "[#{idx + 1}/#{mutants.size}] #{mutant["subject"]} hand=#{mutant["hand_label"]} jev=#{pick&.label} conf=#{pick&.confidence&.round(3)} noul=#{mood&.probability&.round(3)}"
  end
end

if replay_mode
  raise "No tape found at #{TAPE_PATH}; run live first." unless File.exist?(TAPE_PATH)

  tape = Feelings::Tape.from_json(File.read(TAPE_PATH))
  Feelings.replay(tape) { run.call }
else
  tape = Feelings.record { run.call }
  File.write(TAPE_PATH, tape.to_json)
  puts "Saved tape to #{TAPE_PATH}"
end

elapsed = Time.now - start
puts "Elapsed: #{elapsed.round(2)}s"

File.write(RESULTS_PATH, JSON.pretty_generate(
  meta: {
    generated_at: Time.now.utc.iso8601,
    replay: replay_mode,
    elapsed_seconds: elapsed.round(2),
    judge_model: results.first && (results.first[:jev_model] || results.first[:noul_model])
  },
  results: results
))
puts "Saved results to #{RESULTS_PATH}"
