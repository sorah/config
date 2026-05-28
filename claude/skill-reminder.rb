# Reminds Claude to load sorah-guides convention skills before editing code.
# Handles both UserPromptSubmit (general nudge, once per session) and
# PreToolUse on Write/Edit (per-language nudge at the moment a file is touched).
# State is kept per session so each reminder fires at most once.
require 'json'
require 'fileutils'

input = JSON.parse($stdin.read)
event = input['hook_event_name']
session = input['session_id'] || 'unknown'

state_dir = File.join(Dir.home, '.cache', 'claude-skill-reminder')
FileUtils.mkdir_p(state_dir)
state_path = File.join(state_dir, "#{session}.json")
reminded = File.exist?(state_path) ? JSON.parse(File.read(state_path)) : []

def emit(event, context)
  puts JSON.generate('hookSpecificOutput' => { 'hookEventName' => event, 'additionalContext' => context })
end

def mark(reminded, state_path, *keys)
  File.write(state_path, JSON.generate((reminded + keys).uniq))
end

# Maps a file path to the sorah-guides skills whose conventions apply.
def skills_for(path)
  skills = []
  case File.extname(path)
  when '.rb', '.rake', '.gemspec'
    skills << 'ruby'
    skills << 'rails' if path =~ %r{(^|/)(app|config|db|spec)/} || File.basename(path) == 'Gemfile'
  when '.tf', '.tfvars'
    skills << 'terraform'
  when '.ts', '.tsx', '.mts', '.cts'
    skills << 'typescript'
  when '.rs'
    skills << 'rust'
  end
  skills << 'rails' if File.basename(path) == 'Gemfile'
  skills.uniq
end

case event
when 'UserPromptSubmit'
  unless reminded.include?('prompt')
    emit(event, 'This environment provides the sorah-guides convention skills ' \
      '(ruby, rails, terraform, typescript, rust, etc.). Before writing or editing code in any ' \
      'of these languages, invoke the matching /sorah-guides:<lang> skill if it has not been ' \
      'loaded yet this session — its conventions override your defaults.')
    mark(reminded, state_path, 'prompt')
  end
when 'PreToolUse'
  path = input.dig('tool_input', 'file_path')
  exit 0 unless path
  pending = skills_for(path) - reminded
  exit 0 if pending.empty?
  list = pending.map { |s| "/sorah-guides:#{s}" }.join(', ')
  emit(event, "Editing #{File.basename(path)}: load #{list} first if not already loaded this " \
    'session, and follow its conventions for this change.')
  mark(reminded, state_path, *pending)
end
