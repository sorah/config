# frozen_string_literal: true

require 'shellwords'

module AgentBoard
  # PreToolUse/PostToolUse hook for the chief session only. Classifies each tool call and decides
  # by whether the user is present and whether the session has read raw external content, using
  # the editable table in chief-policy.json. Calls it does not classify fall through to settings.
  class Guard
    POLICY = File.join(ROOT, 'chief-policy.json')
    DECISIONS = %w[allow ask deny].freeze
    GH_FIELD_FLAGS = %w[-f -F --field --raw-field --input].freeze
    READ_VERB = /\A(get|list|search|read|fetch|query|find|view|whoami|describe|inspect|analy[sz]e|aggregate|estimate|download)/

    def initialize(store:, policy: JSON.parse(File.read(POLICY)), now: Time.now)
      @store = store
      @policy = policy
      @now = now
    end

    def call(payload)
      case payload.fetch('hook_event_name')
      when 'PreToolUse' then decide(payload)
      when 'PostToolUse' then taint!(payload) && nil
      when 'SessionStart' then clear_taint(payload) && nil
      end
    end

    def classify(tool, input)
      input ||= {}
      case tool
      when 'Bash' then classify_bash(input['command'].to_s)
      when 'Write', 'Edit', 'MultiEdit', 'NotebookEdit' then store_path?(input['file_path'] || input['notebook_path']) ? 'store_write' : nil
      when *@policy.fetch('external_read_tools') then 'external_read'
      when 'Read', 'Grep', 'Glob' then raw_store_path?(input['file_path'] || input['path']) ? 'external_read' : nil
      when /\Amcp__/ then tool.split('__', 3).last.to_s.match?(READ_VERB) ? 'external_read' : 'external_write'
      end
    end

    def tainted?
      File.exist?(taint_file)
    end

    private def decide(payload)
      klass = classify(payload['tool_name'], payload['tool_input'])
      return if klass.nil?

      state = if !Presence.present?(@store, @now) then 'absent'
              elsif tainted? then 'tainted'
              else 'present'
              end
      decision = @policy.dig('classes', klass, state)
      return unless DECISIONS.include?(decision)

      reason = "chief policy: #{klass} while #{state == 'tainted' ? 'present (session has read raw external content)' : state}"
      JSON.generate('hookSpecificOutput' => {'hookEventName' => 'PreToolUse', 'permissionDecision' => decision,
                                             'permissionDecisionReason' => reason})
    end

    # Raw external content in context lasts until the next fresh session.
    private def taint!(payload)
      return unless classify(payload['tool_name'], payload['tool_input']) == 'external_read'

      @store.write_atomically(taint_file, JSON.generate({'at' => @now.iso8601, 'tool' => payload['tool_name']}))
    end

    private def clear_taint(payload)
      FileUtils.rm_f(taint_file) if %w[startup clear].include?(payload['source'])
    end

    private def taint_file
      FileUtils.mkdir_p(@store.path('chief'))
      @store.path('chief', 'taint.json')
    end

    # The strictest class among the command's segments wins.
    private def classify_bash(command)
      classes = segments(command).map(&:strip).reject(&:empty?).map { classify_segment(it) }
      %w[exfil store_write unparseable external_write external_read board_gated].find { classes.include?(it) }
    end

    # Splits on unquoted ; | & and newlines. Command substitutions run even inside double quotes,
    # so their bodies become segments of their own as well.
    private def segments(command)
      out = [+'']
      substitutions = []
      quote = nil
      i = 0
      while i < command.length
        c = command[i]
        if quote == "'"
          quote = nil if c == "'"
          out.last << c
        elsif c == '\\' && quote != "'"
          out.last << c << command[i + 1].to_s
          i += 1
        elsif quote.nil? && "'\"".include?(c)
          quote = c
          out.last << c
        elsif c == '"'
          quote = nil
          out.last << c
        elsif command[i, 2] == '$(' || c == '`'
          closing = c == '`' ? '`' : ')'
          finish = command.index(closing, i + (c == '`' ? 1 : 2)) || command.length
          substitutions << command[(i + (c == '`' ? 1 : 2))...finish]
          out.last << ' '
          i = finish
        elsif quote.nil? && ";|&\n".include?(c)
          out << +''
        else
          out.last << c
        end
        i += 1
      end
      out + substitutions.flat_map { segments(it) }
    end

    private def classify_segment(segment)
      words = Shellwords.split(segment)
      words.shift while words.first&.match?(/\A\w+=/) || %w[env command exec builtin nohup time sudo].include?(words.first)
      program = words.first.to_s
      base = File.basename(program)
      line = ([base] + words.drop(1)).join(' ')
      case
      when @policy.fetch('exfil_commands').include?(base) then 'exfil'
      when base == 'sorah-agent-board' then @policy.fetch('board_gated_subcommands').include?(words[1]) ? 'board_gated' : nil
      when base == 'gh' && words[1] == 'api' then gh_api_class(words.drop(2))
      when @policy.fetch('external_write_commands').any? { line.start_with?(it) } then 'external_write'
      when @policy.fetch('external_read_commands').any? { line.start_with?(it) } then 'external_read'
      when words.any? { store_path?(it) } && segment.match?(/>|\b(tee|cp|mv|rm|sed\s+-i|truncate|dd)\b/) then 'store_write'
      end
    rescue ArgumentError
      'unparseable'
    end

    # gh api defaults to GET, switches to POST when fields are given, and GraphQL can mutate.
    private def gh_api_class(args)
      method = nil
      has_fields = false
      args.each_with_index do |arg, i|
        case arg
        when '-X', '--method' then method = args[i + 1].to_s.upcase
        when /\A--method=(.+)\z/, /\A-X(.+)\z/ then method = Regexp.last_match(1).upcase
        when *GH_FIELD_FLAGS then has_fields = true
        end
      end
      endpoint = args.find { !it.start_with?('-') }
      return 'external_write' if endpoint == 'graphql' && args.join(' ').match?(/\bmutation\b/)
      return 'external_read' if endpoint == 'graphql'

      (method || (has_fields ? 'POST' : 'GET')) == 'GET' ? 'external_read' : 'external_write'
    end

    # Agent transcripts and raw hook payloads hold whatever external content agents read.
    private def raw_store_path?(path)
      return false if path.nil?

      expanded = File.expand_path(path.to_s)
      [File.join(Dir.home, '.claude', 'projects'), @store.path('debug')].any? { expanded.start_with?(it) }
    end

    private def store_path?(path)
      return false if path.nil?

      expanded = File.expand_path(path.to_s)
      @policy.fetch('store_paths').any? { expanded.start_with?(File.join(@store.root, it)) }
    end
  end
end
