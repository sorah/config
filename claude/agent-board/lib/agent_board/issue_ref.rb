# frozen_string_literal: true

module AgentBoard
  # Extracts Linear and GitHub issue references from URLs, branch names and prompt text.
  module IssueRef
    LINEAR_URL = %r{https://linear\.app/[\w-]+/issue/([A-Za-z][A-Za-z0-9]{0,9}-\d{1,7})}
    GITHUB_URL = %r{https://github\.com/([\w.-]+/[\w.-]+)/(issues|pull)/(\d+)}
    LINEAR_KEY = /\b([A-Z][A-Z0-9]{0,9}-\d{1,7})\b/
    BRANCH_LINEAR = %r{(?:\A|/)([a-z][a-z0-9]{0,9})-(\d{1,7})(?:-|\z)}
    BRANCH_GITHUB = %r{(?:\A|/)(\d{1,7})-}

    # Bare keys in prose are ambiguous (UTF-8, SHA-256), so they count only for known Linear team keys.
    def self.from_text(text, team_keys: [])
      return if text.nil?

      if (m = LINEAR_URL.match(text))
        return linear(m[1].upcase, url: m[0])
      end
      if (m = GITHUB_URL.match(text))
        return github(m[1], m[3].to_i, kind: m[2])
      end

      text.scan(LINEAR_KEY).flatten.each do |key|
        return linear(key) if team_keys.include?(key.split('-').first)
      end
      nil
    end

    def self.from_branch(branch, repo: nil, team_keys: [])
      return if branch.nil?

      if (m = BRANCH_LINEAR.match(branch))
        team = m[1].upcase
        return linear("#{team}-#{m[2]}") if team_keys.empty? || team_keys.include?(team)
      end
      if repo && (m = BRANCH_GITHUB.match(branch))
        return github(repo, m[1].to_i, kind: 'issues')
      end
      nil
    end

    def self.linear(key, url: nil)
      {'key' => key, 'url' => url, 'tracker' => 'linear'}
    end

    def self.github(repo, number, kind:)
      {'key' => "#{repo}##{number}", 'url' => "https://github.com/#{repo}/#{kind}/#{number}", 'tracker' => 'github'}
    end

    PINNED_SOURCES = %w[explicit dispatch chief].freeze

    # Records a reference on the session and returns a link event when it becomes the primary issue.
    # Linear wins over GitHub, and a reference the user or chief chose is not replaced automatically.
    def self.attach(session, ref, source:, now:)
      return if ref.nil?

      entry = ref.merge('source' => source, 'at' => now.iso8601)
      session.refs ||= []
      session.refs << entry unless session.refs.any? { it['key'] == entry['key'] }
      current = session.issue
      pinned = PINNED_SOURCES.include?(source)
      replace = current.nil? || pinned ||
                (!PINNED_SOURCES.include?(current['source']) && current['tracker'] != 'linear' && entry['tracker'] == 'linear')
      return unless replace && current&.fetch('key') != entry['key']

      session.issue = entry
      {'at' => now.iso8601, 'kind' => 'link', 'text' => "Linked to #{entry.fetch('key')} (#{source})"}
    end

    # Accepts what a user or agent passes to `link`: a URL, a Linear key, or owner/repo#N.
    def self.parse_explicit(arg)
      from_text(arg) ||
        case arg
        when %r{\A([\w.-]+/[\w.-]+)#(\d+)\z} then github(::Regexp.last_match(1), ::Regexp.last_match(2).to_i, kind: 'issues')
        when /\A[A-Za-z][A-Za-z0-9]{0,9}-\d{1,7}\z/ then linear(arg.upcase)
        end
    end
  end
end
