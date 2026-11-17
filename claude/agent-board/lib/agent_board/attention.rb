# frozen_string_literal: true

module AgentBoard
  # Items the chief of staff brings to the user's attention: decisions to make, drafts awaiting
  # approval, suggestions. Numbers are never reused, so "post 4" always means the same draft.
  class Attention
    KINDS = %w[decide draft suggest].freeze
    # Kinds that wait on the user and so count toward the needs-you number.
    BLOCKING = %w[decide draft].freeze
    OUTCOMES = %w[done posted dropped].freeze

    def initialize(store:)
      @store = store
      @file = store.path('chief', 'attention.json')
      FileUtils.mkdir_p(File.dirname(@file))
    end

    def add(kind:, text:, agent: nil, ref: nil, now: Time.now)
      raise CLI::Error, "attention: kind must be one of #{KINDS.join(', ')}" unless KINDS.include?(kind)

      transaction do |data|
        id = data.fetch('next_id')
        data['next_id'] = id + 1
        data['items'] << {
          'id' => id, 'kind' => kind, 'text' => Text.clean(text, max: 300, single_line: true),
          'agent' => agent && Text.clean(agent, max: 40, single_line: true),
          'ref' => ref && Text.clean(ref, max: 60, single_line: true),
          'at' => now.iso8601, 'resolved_at' => nil, 'outcome' => nil
        }
        id
      end
    end

    def resolve(id, outcome:, now: Time.now)
      raise CLI::Error, "attention: outcome must be one of #{OUTCOMES.join(', ')}" unless OUTCOMES.include?(outcome)

      transaction do |data|
        item = data['items'].find { it['id'] == id && it['resolved_at'].nil? }
        raise CLI::Error, "attention: no open item ##{id}" if item.nil?

        item.merge!('resolved_at' => now.iso8601, 'outcome' => outcome)
      end
    end

    def open_items
      read.fetch('items').select { it['resolved_at'].nil? }
    end

    private def read
      File.exist?(@file) ? JSON.parse(File.read(@file)) : {'next_id' => 1, 'items' => []}
    end

    private def transaction
      File.open(@store.path('locks', 'attention.lock'), File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_EX)
        data = read
        result = yield(data)
        @store.write_atomically(@file, JSON.pretty_generate(data))
        result
      end
    end
  end
end
