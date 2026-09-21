#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Parses a mutant `alive` report (mutant's default text output for
# surviving mutants) into structured records and applies a rule-based hand
# classification. Writes mutants.json into the same directory as this
# script, for run_jev.rb to pick up.
#
# Usage:
#   EXPERIMENT_DIR=/path/to/experiment \
#   MODULE_SOURCE=/path/to/app/services/foo.rb \
#   MODULE_NAMESPACE=Foo::Bar \
#     ruby parse_mutants.rb [alive_report_relative_path]
#
# Arguments (all overridable by env var; first CLI arg wins for the alive
# report path):
#   EXPERIMENT_DIR   - deletion-test experiment directory (has a mutation/
#                       subdirectory holding the alive report)
#   MODULE_SOURCE    - absolute path to the original module source file
#   MODULE_NAMESPACE - the module/class namespace prefix mutant subjects
#                       are reported under, e.g. "Foo::Bar" for
#                       "Foo::Bar.some_method" or "Foo::Bar#some_method".
#                       Used to strip the prefix off "##### " subject
#                       headers and to recover the subject name from
#                       "evil:" mutant ids when the header is ambiguous.
#   ALIVE_REPORT     - path (absolute, or relative to EXPERIMENT_DIR/mutation)
#                       to the alive-mutants report. Defaults to
#                       "mutation/contract_spec_alive.txt" under
#                       EXPERIMENT_DIR. May also be passed as ARGV[0].

require "json"

EXP = ENV.fetch("EXPERIMENT_DIR") { abort "Set EXPERIMENT_DIR (deletion-test experiment dir)." }
SOURCE = ENV.fetch("MODULE_SOURCE") { abort "Set MODULE_SOURCE (path to the original module file)." }
NAMESPACE = ENV.fetch("MODULE_NAMESPACE") { abort "Set MODULE_NAMESPACE (e.g. Foo::Bar)." }

alive_arg = ARGV[0] || ENV["ALIVE_REPORT"] || "mutation/contract_spec_alive.txt"
ALIVE = alive_arg.start_with?("/") ? alive_arg : File.join(EXP, alive_arg)

# Regex fragment matching a bare method name, e.g. "raw_window_for", "for",
# "output_for?". Override via METHOD_NAME_PATTERN if the module uses names
# this doesn't cover (e.g. names with digits already work; this excludes
# operator-style method names like `[]` or `==`).
METHOD_NAME_PATTERN = ENV.fetch("METHOD_NAME_PATTERN", "[a-zA-Z_][a-zA-Z0-9_]*[?!]?")

lines = File.readlines(ALIVE, chomp: true)

# Extract method bodies from the source, keyed by method name, from
# top-level `def` lines (including inside `class << self` blocks). A small
# hand-rolled scanner: it does not parse Ruby, it counts `def`/block-opener
# keywords against `end` keywords. It works for straight-line method bodies
# without heredocs that contain a bare "end" on their own line; adjust
# `opens_block` below if the target module needs more.
def extract_methods(source_lines, method_name_pattern)
  methods = {}
  current_name = nil
  current_lines = []
  depth = 0
  in_method = false
  def_re = /^\s*def\s+(#{method_name_pattern})/

  source_lines.each do |line|
    if !in_method && line =~ def_re
      current_name = Regexp.last_match(1)
      current_lines = [line]
      depth = 1
      in_method = true
      next
    end

    if in_method
      current_lines << line
      stripped = line.strip
      opens_block = !stripped.start_with?("#") && (
        stripped =~ /^(def|if|unless|case|begin|class|module)\b/ ||
        stripped =~ /\bdo(\s*\|[^|]*\|)?\s*\z/
      )
      depth += 1 if opens_block
      depth -= 1 if stripped == "end"
      if depth <= 0
        methods[current_name] = current_lines.join("\n")
        in_method = false
        current_name = nil
        current_lines = []
      end
    end
  end
  methods
end

method_bodies = extract_methods(File.readlines(SOURCE, chomp: true), METHOD_NAME_PATTERN)

subject_header_re = /\A#{Regexp.escape(NAMESPACE)}[.#]/
subject_from_id_re = /#{Regexp.escape(NAMESPACE)}[.#](#{METHOD_NAME_PATTERN}):/

mutants = []
current_subject = nil
i = 0
while i < lines.length
  line = lines[i]

  if line.start_with?("##### ")
    current_subject = line.sub("##### ", "").sub(subject_header_re, "").strip
    i += 1
    next
  end

  if line.start_with?("evil:")
    # evil:Subject:path:line:hash
    id = line.sub(/^evil:/, "").strip
    subject_from_id = id[subject_from_id_re, 1]
    subject = subject_from_id || current_subject

    i += 1
    # next line should be the ----- separator
    i += 1 while i < lines.length && lines[i].start_with?("-----")
    diff_lines = []
    while i < lines.length && !lines[i].start_with?("-----")
      diff_lines << lines[i]
      i += 1
    end
    # consume trailing ----- separator
    i += 1 while i < lines.length && lines[i].start_with?("-----")

    changed = diff_lines.select { |l| l.start_with?("-") || l.start_with?("+") }
                         .reject { |l| l.start_with?("---") || l.start_with?("+++") }
    mutants << {
      id: id,
      subject: subject,
      diff: diff_lines.join("\n"),
      changed: changed
    }
    next
  end

  i += 1
end

# === ADAPT: rule-based hand classification =================================
# This is the one part of the pipeline that is inherently module-specific:
# a set of deterministic rules that assign each surviving mutant one of the
# three labels used downstream (see LABELS in run_jev.rb — keep the two
# lists in sync). Replace the body of `classify` for your module, keeping
# the three examples below as illustration of the shape a rule takes:
#
#   1. A structural rule independent of subject: a diff that touches
#      exactly one original line and that line is a logging call is
#      "log_only" regardless of which method it's in.
#   2. A textual rule: specific literals or fragments known (from reading
#      the method) to change behavior wherever they appear.
#   3. A subject-scoped rule: a fragment that only means "behavior_change"
#      in the context of one particular method, because the same fragment
#      elsewhere would be a no-op.
#
# Anything not matched falls through to "equivalent" — verify that default
# is actually the right most-common-case for your module before trusting it.
def classify(m)
  changed = m[:changed]
  changed_text = changed.join("\n")

  minus_lines = changed.select { |l| l.start_with?("-") }
  plus_lines = changed.select { |l| l.start_with?("+") }

  # Example rule 1 (structural, subject-independent): the diff's changed
  # lines touch a Rails.logger.warn( line, or remove it, and touch nothing
  # else — i.e. exactly one original line was touched (0 or 1 replacement
  # line), and that original line is the logger call.
  log_only = minus_lines.size == 1 && plus_lines.size <= 1 && minus_lines.first =~ /Rails\.logger\.warn\(/
  return "log_only" if log_only

  # Example rule 2 (textual) and rule 3 (subject-scoped), combined as in
  # the original pilot:
  if changed_text.include?("raw / 5") ||
     changed_text.include?("legate: nil") ||
     (m[:subject] == "raw_window_for" && changed.any? { |l| l.include?("value.is_a?(Numeric) && value.positive?") })
    return "behavior_change"
  end

  "equivalent"
end
# === END ADAPT ==============================================================

mutants.each do |m|
  m[:hand_label] = classify(m)
  m[:method_source] = method_bodies[m[:subject]]
end

puts "Total mutants: #{mutants.size}"
by_subject = mutants.group_by { |m| m[:subject] }
by_subject.each { |s, ms| puts "  #{s}: #{ms.size} (methods found: #{method_bodies.key?(s)})" }

counts = mutants.group_by { |m| m[:hand_label] }.transform_values(&:size)
puts "Hand label counts: #{counts}"

missing_source = mutants.select { |m| m[:method_source].nil? }
if missing_source.any?
  puts "WARNING: missing method source for subjects: #{missing_source.map { |m| m[:subject] }.uniq}"
end

out_path = File.join(__dir__, "mutants.json")
File.write(out_path, JSON.pretty_generate(mutants))
puts "Wrote #{mutants.size} mutants to #{out_path}"
