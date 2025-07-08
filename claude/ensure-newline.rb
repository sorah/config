require 'json'
path = JSON.parse($stdin.read).dig('tool_input', 'file_path')
unless path
  puts "No file path provided"
  exit 1
end
buf = File.read(path)
unless buf[-1] == "\n"
  puts "Ensuring newline: #{path.inspect}"
  File.open(path, 'a') do |io|
    io.write("\n")
  end
end
