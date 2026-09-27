# frozen_string_literal: true
# Wraps scripts/dump.rb in one outer transaction that's always rolled back,
# so a dump run (baseline or candidate) leaves the database untouched. This
# matters when the probe creates records with uniqueness constraints (e.g. a
# fixed name) — without the rollback, one arm's rows persist and the next
# arm's setup fails on that constraint.
probe_path, impl_path, out_path, dump_script = ARGV
raise "usage: run_baseline_wrapper.rb <probe> <impl> <out> <dump_script>" unless dump_script

ActiveRecord::Base.transaction(requires_new: true) do
  ARGV.replace([ probe_path, impl_path, out_path ])
  load dump_script
  raise ActiveRecord::Rollback
end
