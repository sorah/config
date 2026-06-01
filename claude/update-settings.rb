# Builds claude/settings.jsonnet with jrsonnet and merges the result into
# ~/.claude/settings.json, preserving keys Claude Code writes at runtime
# (alwaysThinkingEnabled, effortLevel, runtime-approved permissions, ...).
#
# Merge rules:
#   - Hashes are deep-merged; jsonnet wins on scalar conflicts, live-only keys kept.
#   - Hook-event arrays are merged by `_id` (jsonnet groups replace the matching
#     live group; live-only groups are preserved). Legacy groups without `_id` are
#     matched structurally so they are not duplicated on first run. `_id` is kept in
#     the output so it round-trips on subsequent runs.
#   - Other arrays (e.g. permissions.allow/deny) are unioned, base order first.
require 'json'

SOURCE = File.expand_path('settings.jsonnet', __dir__)
TARGET = File.expand_path('~/.claude/settings.json')

def deep_merge(base, over)
  return merge_hash(base, over) if base.is_a?(Hash) && over.is_a?(Hash)
  return merge_array(base, over) if base.is_a?(Array) && over.is_a?(Array)
  over
end

def merge_hash(base, over)
  out = base.dup
  over.each do |key, value|
    out[key] = base.key?(key) ? deep_merge(base[key], value) : value
  end
  out
end

def merge_array(base, over)
  return upsert_groups(base, over) if (base + over).all? { |e| e.is_a?(Hash) }
  base | over
end

# Identifies hook groups by `_id`, falling back to structural equality so legacy
# groups predating the `_id` convention are updated in place instead of duplicated.
def upsert_groups(base, over)
  result = base.dup
  over.each do |group|
    index = match_index(result, group)
    if index
      result[index] = group
    else
      result << group
    end
  end
  result
end

def match_index(groups, group)
  id = group['_id']
  if id
    by_id = groups.index { |g| g.is_a?(Hash) && g['_id'] == id }
    return by_id if by_id
  end
  shape = without_id(group)
  groups.index { |g| g.is_a?(Hash) && without_id(g) == shape }
end

def without_id(group)
  group.reject { |key, _| key == '_id' }
end

def build_settings
  output = IO.popen(['jrsonnet', SOURCE], &:read)
  raise "jrsonnet failed for #{SOURCE}" unless $?.success?
  JSON.parse(output)
end

def load_existing
  return {} unless File.exist?(TARGET)
  JSON.parse(File.read(TARGET))
end

def write_atomically(path, data)
  tmp = "#{path}.#{Process.pid}.tmp"
  File.write(tmp, "#{JSON.pretty_generate(data)}\n")
  File.rename(tmp, path)
end

merged = deep_merge(load_existing, build_settings)
write_atomically(TARGET, merged)
puts "Updated #{TARGET}"
