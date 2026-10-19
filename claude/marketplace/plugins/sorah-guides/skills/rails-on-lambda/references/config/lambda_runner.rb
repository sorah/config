# frozen_string_literal: true

require 'json'
require 'open3'

# Runs {"run": ["bundle", "exec", "rake", "db:migrate"]} as a subprocess and returns its output and exit status.
module CommandRunner
  def self.handle(event:, context:)
    raise "No command provided" unless event['run']

    run(event['run'], context:)
  end

  def self.run(cmd, context:)
    $stdout.puts "RUNCMD #{context.aws_request_id} #{JSON.generate(cmd)}"
    t = Time.now.utc
    cmd = Array(cmd)
    raise "invalid argument" if cmd.empty? || !cmd.all? { |e| e.is_a?(String) }

    $stdout.sync = true
    buf = +''
    status = Open3.popen2e(*cmd) do |stdin, stdouterr, waiter|
      stdin.close
      while (line = stdouterr.gets)
        buf << line
        $stdout.puts line
      end
      waiter.value
    end
    $stdout.puts "RUNCMD-OK #{context.aws_request_id}"
    # A synchronous invocation response is limited to 6 MB.
    {ok: status.success?, duration: Time.now.utc - t, output: buf.bytesize > 5000000 ? buf[..5000000] : buf, status: status.exitstatus, signal: status.termsig}
  end
end
