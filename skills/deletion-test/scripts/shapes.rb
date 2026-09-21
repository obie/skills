# frozen_string_literal: true
# Usage: bin/rails runner scripts/shapes.rb <probe.rb> <out.json>
#
# Dumps real, representative input shapes for a deletion-test regeneration
# grid (scripts/dump.rb consumes the output). Pulls from whatever the
# component under test actually reads at runtime (a live catalog, a config
# table, prod/dev DB rows) so the synthetic grid in dump.rb includes shapes
# that really occur, not only invented edge cases.
#
# A "probe" is a plain Ruby file, specific to the component you are
# deletion-testing, that defines a top-level method:
#
#   def shapes
#     { "some-id" => { "raw" => 123, "cap" => 456 }, ... }
#   end
#
# The keys and inner hash shape are yours to define — they only need to
# match what your probe's dump.rb counterpart expects as "shapes.json".
# Wrap any live/DB read in a rescue so a missing dev fixture doesn't blow
# up the whole run; warn and continue with what you have.
#
# Worked example (from the Openrouter::ContextWindowEnv pilot):
#
#   def shapes
#     ids = %w[x-ai/grok-4.6 google/gemini-3.7-pro anthropic/claude-opus-5]
#     catalog = Openrouter::ModelCatalog.new
#     result = ids.to_h { |id| [id, { "raw" => catalog.context_length(id), "cap" => catalog.max_completion_tokens(id) }] }
#     begin
#       Legate.where.not(custom_model_id: [nil, ""]).distinct.pluck(:custom_model_id).each do |m|
#         bare = m.sub(%r{@preset/.*\z}, "")
#         result[bare] ||= { "raw" => catalog.context_length(bare), "cap" => catalog.max_completion_tokens(bare) }
#       end
#     rescue StandardError => e
#       warn "legate scan skipped: #{e.class}: #{e.message}"
#     end
#     result
#   end

probe_path, out_path = ARGV
raise "usage: shapes.rb <probe.rb> <out.json>" unless probe_path && out_path
raise "probe not found: #{probe_path}" unless File.exist?(probe_path)

load probe_path
raise "#{probe_path} must define a top-level `shapes` method returning a Hash" unless respond_to?(:shapes)

result = shapes
raise "shapes must return a Hash, got #{result.class}" unless result.is_a?(Hash)

File.write(out_path, JSON.pretty_generate(result))
puts "#{result.size} shapes -> #{out_path}"
result.each { |k, v| puts "  #{k}: #{v.inspect}" }
