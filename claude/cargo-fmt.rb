require 'json'
paths = [*JSON.parse($stdin.read).dig('tool_input', 'file_path')].compact
if paths.empty?
  puts "No file path provided"
  exit 1
end
paths.each do |path|
  next unless path.end_with?('.rs')
  IO.popen(["cargo", "locate-project"])
end
