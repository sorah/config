# frozen_string_literal: true

module AgentBoard
  # Condenses a session's timeline to outcomes and the user's real inputs, newest first.
  module Recap
    OUTCOMES = %w[dispatch link plan commit pr ask wait message error parked resumed report cleared].freeze
    # A prompt right after one of these is the user answering the agent.
    AWAITING = %w[ask wait blocked].freeze
    LIMIT = 12

    # events: oldest first.
    def self.build(events)
      recap = []
      previous = nil
      events.each_with_index do |event, i|
        entry = entry_for(event, previous, first_prompt: events.find { it['kind'] == 'prompt' }.equal?(event))
        recap << entry if entry && recap.last&.values_at('kind', 'text') != entry.values_at('kind', 'text')
        previous = event unless %w[summary notification].include?(event['kind'])
        recap.reject! { it['kind'] == 'check' && it['text'] == entry['text'] && !it.equal?(entry) } if entry&.dig('kind') == 'check'
        _ = i
      end
      recap.last(LIMIT).reverse
    end

    def self.entry_for(event, previous, first_prompt:)
      kind = event['kind']
      text = event['text'].to_s
      case kind
      when 'prompt'
        return if !Presence.user_prompt?(text)
        return relabel(event, 'started', text) if first_prompt
        return relabel(event, 'answered', text) if previous && AWAITING.include?(previous['kind'])

        nil
      when 'step' then text.end_with?('→ done') ? event : nil
      when 'blocked' then text.start_with?('question:', 'plan:') ? event : nil
      when 'check' then text.end_with?('passed') ? relabel(event, 'check', text.sub(/ passed\z/, ' ✓')) : relabel(event, 'check', text)
      when *OUTCOMES then event
      end
    end

    def self.relabel(event, kind, text)
      event.merge('kind' => kind, 'text' => first_sentence(text))
    end

    def self.first_sentence(text)
      line = text.lines.first.to_s.strip
      line[/\A.{1,160}?[.!?](?=\s|\z)/] || line[0, 160]
    end
  end
end
