# frozen_string_literal: true

module AgentBoard
  # Normalizes text that came from agents or third parties before it is displayed or stored.
  module Text
    # C0/C1 controls (terminal escapes) and bidi overrides that can disguise what a line says.
    UNSAFE = /[\u0000-\u0008\u000b-\u001f\u007f-\u009f‪-‮⁦-⁩​-‏﻿]/
    URL = %r{\b(?:https?|ftp|file)://\S+}i

    def self.clean(value, max: nil, single_line: false, strip_urls: false)
      return value unless value.is_a?(String)

      text = value.gsub(UNSAFE, '')
      text = text.gsub(/\s*\n\s*/, ' ') if single_line
      text = text.gsub(URL, '[link]') if strip_urls
      text = text.strip
      max && text.length > max ? "#{text[0, max - 1]}…" : text
    end

    # Markdown from agents' turn summaries reduced to readable plain text.
    def self.plain(markdown)
      markdown.to_s
        .gsub(/```.*?```/m, ' ')
        .gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\\1')
        .gsub(/^[ \t]{0,3}(?:#+|>|[-*+]|\d+[.)])[ \t]+/, '')
        .gsub(/(\*\*|__|\*|_|`|~~)(?=\S)(.+?)(?<=\S)\1/, '\\2')
        .gsub(/^[ \t]*\|?(?:[ \t]*:?-{3,}:?[ \t]*\|)+[ \t]*$/, '')
        .gsub(/\|/, ' ')
        .gsub(/[ \t]+/, ' ')
        .lines.map(&:strip).join("\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end

    # The first sentence or two of plain text, for one-line displays.
    def self.brief(text, max: 200)
      flat = text.to_s.gsub(/\s+/, ' ').strip
      sentences = flat.scan(/.+?(?:[.!?](?=\s|\z)|\z)/).map(&:strip)
      out = sentences.first.to_s
      out = "#{out} #{sentences[1]}" if sentences[1] && (out.length + sentences[1].length) < max
      clean(out, max:)
    end

    # Applies clean to every string in a JSON-like structure.
    def self.deep_clean(value)
      case value
      when String then clean(value)
      when Array then value.map { deep_clean(it) }
      when Hash then value.transform_values { deep_clean(it) }
      else value
      end
    end
  end
end
