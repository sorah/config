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
