# frozen_string_literal: true

module AgentBoard
  # The name the user gave a Claude Code session (/rename or --name), read from the
  # `custom-title` / `agent-name` records in its transcript. Only bytes appended since the last
  # read are scanned, and only those record types are parsed.
  module SessionName
    MARKERS = ['"type":"custom-title"', '"type":"agent-name"'].freeze

    def self.for(store, session)
      path = session.transcript_path
      return if path.nil? || !File.file?(path)

      cache_file = store.path('cache', 'names', "#{session.id}.json")
      cache = File.exist?(cache_file) ? JSON.parse(File.read(cache_file)) : {}
      offset = cache['offset'].to_i
      size = File.size(path)
      offset = 0 if size < offset
      return cache['name'] if size == offset

      name = cache['name']
      File.open(path) do |f|
        f.seek(offset)
        f.each_line do |line|
          next unless MARKERS.any? { line.include?(it) }

          record = JSON.parse(line)
          name = record['customTitle'] || record['agentName'] || name
        rescue JSON::ParserError
          next
        end
        offset = f.pos
      end
      FileUtils.mkdir_p(File.dirname(cache_file))
      store.write_atomically(cache_file, JSON.generate({'offset' => offset, 'name' => name}))
      name && Text.clean(name, max: 40, single_line: true)
    end
  end
end
