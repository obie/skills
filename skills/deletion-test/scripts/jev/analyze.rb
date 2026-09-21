#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Prints summary numbers, a confusion matrix, and calibration tables from
# jev_triage.json (produced by run_jev.rb).
#
# Usage:
#   EXPERIMENT_DIR=/path/to/experiment ruby analyze.rb

require "json"

EXP = ENV.fetch("EXPERIMENT_DIR") { abort "Set EXPERIMENT_DIR (deletion-test experiment dir)." }
data = JSON.parse(File.read(File.join(EXP, "mutation/jev_triage.json")))
results = data["results"]

LABELS = %w[equivalent log_only behavior_change]

n = results.size
agree = results.count { |r| r["jev_label"] == r["hand_label"] }
high_conf = results.select { |r| r["jev_confidence"] && r["jev_confidence"] >= 0.8 }
agree_high = high_conf.count { |r| r["jev_label"] == r["hand_label"] }
below_06 = results.count { |r| r["jev_confidence"] && r["jev_confidence"] < 0.6 }

puts "n=#{n} judge_model=#{data["meta"]["judge_model"]} elapsed=#{data["meta"]["elapsed_seconds"]}s"
puts "Overall agreement: #{agree}/#{n} = #{(100.0*agree/n).round(1)}%"
puts "High-confidence (>=0.8) subset: #{high_conf.size} mutants, agreement #{agree_high}/#{high_conf.size} = #{high_conf.empty? ? "n/a" : (100.0*agree_high/high_conf.size).round(1).to_s + "%"}"
puts "Jev confidence < 0.6: #{below_06}"

puts "\nConfusion matrix (rows=hand, cols=jev):"
matrix = Hash.new(0)
LABELS.each do |h|
  row = LABELS.map { |j| matrix[[h, j]] }
end
results.each { |r| matrix[[r["hand_label"], r["jev_label"]]] += 1 }
printf("%-18s %10s %10s %10s\n", "hand\\jev", *LABELS)
LABELS.each do |h|
  printf("%-18s %10d %10d %10d\n", h, *LABELS.map { |j| matrix[[h, j]] })
end

puts "\nCalibration by Jev confidence bucket:"
buckets = { "<0.6" => 0...0.6, "0.6-0.8" => 0.6...0.8, ">=0.8" => 0.8..1.0 }
buckets.each do |name, range|
  subset = results.select { |r| r["jev_confidence"] && range.cover?(r["jev_confidence"]) }
  correct = subset.count { |r| r["jev_label"] == r["hand_label"] }
  puts "  #{name}: n=#{subset.size} accuracy=#{subset.empty? ? "n/a" : (100.0*correct/subset.size).round(1).to_s + "%"}"
end

puts "\nCalibration by noul probability bucket (vs hand_label==behavior_change):"
buckets.each do |name, range|
  subset = results.select { |r| r["noul_probability"] && range.cover?(r["noul_probability"]) }
  correct = subset.count { |r| (r["hand_label"] == "behavior_change") == range.cover?(r["noul_probability"]) && r["hand_label"] == "behavior_change" }
  # accuracy here = fraction where binary(noul>=0.5-ish threshold membership) matches hand label behavior_change
  matches = subset.count { |r| (r["hand_label"] == "behavior_change") }
  puts "  #{name}: n=#{subset.size} actually_behavior_change=#{matches} (#{subset.empty? ? "n/a" : (100.0*matches/subset.size).round(1).to_s + "%"})"
end

puts "\nDisagreements:"
disagreements = results.select { |r| r["jev_label"] != r["hand_label"] }
puts "count=#{disagreements.size}"
disagreements.each do |r|
  puts "---"
  puts "id=#{r["id"].split(":").last} subject=#{r["subject"]} hand=#{r["hand_label"]} jev=#{r["jev_label"]} conf=#{r["jev_confidence"]} noul=#{r["noul_probability"]}"
  puts "probs=#{r["jev_probabilities"]}"
  puts r["changed"].join("\n")
end
