# frozen_string_literal: true
# Usage: bin/rails runner scripts/dump.rb <probe.rb> <impl_path> <out.json>
#
# Generic behavioral-dump harness for a deletion-test regeneration arm.
# Loads <impl_path> as the component under test (in place of whatever it
# normally is), stubs its dependencies per the probe, calls every public
# method the probe names over an input grid, and dumps the results to
# JSON. Run it once against the ORIGINAL implementation to produce the
# baseline, then once per candidate; diff the two JSON files (score.sh
# does this diff for you) to get a pure behavioral delta with no test
# framework in the way — this catches divergence a spec (contract or
# original) doesn't happen to exercise.
#
# A "probe" is a plain Ruby file, specific to the component under test,
# that defines three top-level methods:
#
#   def stub!
#     # Replace the component's dependencies with deterministic fakes.
#     # Read scripts/shapes.rb's output here if you need real shapes:
#     #   shapes = JSON.parse(File.read(File.join(__dir__, "shapes.json")))
#     # Runs once, before the candidate implementation is loaded.
#   end
#
#   def unload_and_load!(impl_path)
#     # Remove the previously-defined constant (if any) and `load` impl_path
#     # so the file under test is re-evaluated fresh each run.
#   end
#
#   def inputs
#     # Return an Array of arbitrary argument-tuples (arrays or hashes) to
#     # feed to each method under test. Include: a synthetic grid across the
#     # plausible range, boundary/degenerate values (0, negative, nil,
#     # empty string, wrong type, a value that makes a dependency raise),
#     # and the real shapes from shapes.rb.
#   end
#
#   def call(method_name, args)
#     # Invoke the component under test with one input tuple; rescue
#     # StandardError and return {"raised" => e.class.name} so a raise is
#     # itself a comparable behavior instead of crashing the harness.
#   end
#
#   def methods_under_test
#     # Array of method-name symbols/strings to call for every input.
#   end
#
# Worked example (from the Openrouter::ContextWindowEnv pilot) is in
# references/scoring.md, "Building the grid (the probe)".

probe_path, impl_path, out_path = ARGV
unless probe_path && impl_path && out_path
  raise "usage: dump.rb <probe.rb> <impl_path> <out.json>"
end
raise "probe not found: #{probe_path}" unless File.exist?(probe_path)
raise "impl not found: #{impl_path}" unless File.exist?(impl_path)

load probe_path
%i[stub! unload_and_load! inputs call methods_under_test].each do |m|
  raise "#{probe_path} must define top-level `#{m}`" unless respond_to?(m)
end

stub!
unload_and_load!(impl_path)

all_inputs = inputs
raise "probe#inputs must return an Array" unless all_inputs.is_a?(Array)

methods = methods_under_test
result = {}
all_inputs.each do |args|
  key = args.inspect
  result[key] = methods.each_with_object({}) do |m, row|
    row[m.to_s] = call(m, args)
  end
end

File.write(out_path, JSON.pretty_generate(result.sort.to_h))
puts "#{result.size} inputs x #{methods.size} methods -> #{out_path}"
