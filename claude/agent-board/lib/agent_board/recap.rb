# frozen_string_literal: true

module AgentBoard
  # Condenses a session's timeline to outcomes and the user's real inputs, newest first: task
  # changes, milestones, decisions and concise reports, without routine prompts or raw summaries.
  module Recap
    LIMIT = 12
    OUTCOMES = %w[dispatch link plan commit pr did decide ask wait message error parked report cleared].freeze
    # A prompt right after one of these is the user answering the agent.
    AWAITING = %w[ask wait blocked decide].freeze

    # events: oldest first.
    def self.build(events)
      first_prompt = events.find { it['kind'] == 'prompt' && Presence.user_prompt?(it['text']) }
      recap = []
      previous = nil
      events.each do |event|
        entry = entry_for(event, previous, first_prompt: event.equal?(first_prompt))
        previous = event unless %w[summary title].include?(event['kind'])
        next if entry.nil? || recap.last&.values_at('kind', 'text') == entry.values_at('kind', 'text')

        # Only the latest result of a repeated check matters.
        recap.reject! { it['kind'] == 'check' && check_command(it) == check_command(entry) } if entry['kind'] == 'check'
        recap << entry
      end
      recap.last(LIMIT).reverse
    end

    def self.entry_for(event, previous, first_prompt:)
      text = event['text'].to_s
      case event['kind']
      when 'prompt'
        return unless Presence.user_prompt?(text)
        return relabel(event, 'started', text) if first_prompt
        return relabel(event, 'answered', text) if previous && AWAITING.include?(previous['kind'])

        nil
      when 'step' then text.end_with?('→ todo') ? nil : event
      when 'blocked' then text.start_with?('question:', 'plan:') ? relabel(event, 'ask', text) : nil
      when 'check' then text.end_with?('passed') ? nil : relabel(event, 'check', text)
      when *OUTCOMES then relabel(event, event['kind'], text)
      end
    end

    def self.relabel(event, kind, text)
      event.merge('kind' => kind, 'text' => first_sentence(text))
    end

    def self.check_command(entry) = entry['text'].sub(/ failed \(.*\)\z/, '')

    def self.first_sentence(text)
      line = Text.plain(text).lines.first.to_s.strip
      line[/\A.{1,160}?[.!?](?=\s|\z)/] || line[0, 160]
    end
  end
end
