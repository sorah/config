require 'json'
paths = [*JSON.parse($stdin.read).dig('tool_input', 'file_path')].compact
if paths.empty?
  puts "No file path provided"
  exit 1
end

paths.each do |path|
  if path.end_with?('.rs')
    dir = File.dirname(path)
    project_json = IO.popen(["cargo", "locate-project", chdir: dir], &:read)
    next unless $?.success?
    project_root = File.dirname(JSON.parse(project_json).fetch("root"))
    system("cargo", "fmt", "--", path, chdir: project_root, exception: true)
  end

  if path.end_with?('.go')
    system("goimports", "-w", path, exception: true)
    system("go", "fmt", "--", path, exception: true)
  end
end
