require 'logger'
require 'socket'
require 'thread'
require 'json'
require 'aws-sdk'
require 'fluent-logger'

@noop = ENV['NOOP'] == '1'

$stdout.sync = true

AWS_REGION = 'ap-northeast-1'
AWS_PROFILE = 'cron-wakeup'
CURRENT_TXT_S3_BUCKET =  'sorah-userland'
CURRENT_TXT_S3_KEY =  'wakeup/current.txt'

RESULT_S3_BUCKET = 'sorah-userland'
RESULT_S3_PREFIX = 'wakeup/result'

SQS_QUEUE_NAME = 'sorah-wakeup'

LOGS_LOG_GROUP = 'sorah-wakeup'
LOGS_LOG_STREAM = 'log'

def tweet(*texts)
  Thread.new do
    begin
      logger = Fluent::Logger::FluentLogger.new('twitter', host: 'boston.her', port: 19248)
      texts.each do |text|
        puts "TWEET: #{text}"
        logger.post('sorah-wakeup', message: text)
      end
    rescue Exception => e
      warn "Error while tweeting: #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
    end
  end
end

def latest_sequence_token
  @logs_lock.synchronize do
    @logs.describe_log_streams(log_group_name: LOGS_LOG_GROUP, log_stream_name_prefix: LOGS_LOG_STREAM).log_streams.find { |_| _.log_stream_name == LOGS_LOG_STREAM }.upload_sequence_token
  end
end

def publish_log(message_id, obj)
  publish_log_cloudwatch(obj)
  publish_log_s3(message_id, obj)
end

def publish_log_cloudwatch(obj)
  msg = obj.to_json
  @logs_lock.synchronize do
    puts "LOG: #{msg}"
    begin
      resp = @logs.put_log_events(
        log_group_name: LOGS_LOG_GROUP,
        log_stream_name: LOGS_LOG_STREAM,
        sequence_token: @logs_sequence_token,
        log_events: [
          {timestamp: (Time.now.to_f * 1000).to_i, message: msg},
        ]
      )
    rescue Exception => e
      warn "Error while publishing log to CloudWatchLogs: #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
      return
    end

    @logs_sequence_token = resp.next_sequence_token
  end
end

def publish_log_s3(msgid, obj)
  @s3.put_object(bucket: RESULT_S3_BUCKET, key: "#{RESULT_S3_PREFIX}/#{msgid}", content_type: 'application/json', body: obj.to_json)
rescue Exception => e
  warn "Error while publishing log to S3: #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
end

def nw_locate
  `sorah-nw-simple-locate`.chomp
end

def current_track
  if @noop
    return 32.times.map { ('a'..'z').to_a.sample }.join
  end

  scpt = <<-EOS
  var it = Application("iTunes");
  var track = it.currentTrack();
  var res = "Nothing playing";
  if (track && it.playerState() == "playing") {
    res = track.name() + " - " + track.artist() + " (vol=" + Application("iTunes").soundVolume() + ")";
  }

  res
  EOS

  IO.popen(["osascript", "-l", "JavaScript"], 'w+') do |io|
    io.puts scpt
    io.close_write
    io.read.chomp
  end
end

def alarm!
  return if @noop
  scpt = <<-EOS
  var it = Application("iTunes");
  var state = it.playerState()

  var shouldChangePlaylist = it.currentPlaylist().name() != "Music" && it.currentPlaylist().name() != "__Smart";

  if (shouldChangePlaylist) {
    it.playlists["Music"].play();

    var shuffleMenu = Application("System Events").processes['iTunes'].menuBars[0].menuBarItems['Controls'].menus[0].menuItems['Shuffle'].menus[0];
    shuffleMenu.menuItems['On'].click();
    shuffleMenu.menuItems['Songs'].click();
  } else {
    it.play();
  }

  it.soundVolume = 100;
  EOS

  IO.popen(["osascript", "-l", "JavaScript"], 'w+') do |io|
    io.puts scpt
    io.close_write
    io.read
  end
end

def wakeup!(run_id: Time.now.to_s)
  alarm!

  cur = current_track
  puts "Woke up, playing: #{cur}"
  update_current_track(cur)

  tweet "@sorahers #sorah_wakeup #{run_id}", "@sora_h #sorah_wakeup #{run_id}"

  cur
end

def update_current_track(cur = current_track)
  @s3.put_object(bucket: CURRENT_TXT_S3_BUCKET, key: CURRENT_TXT_S3_KEY, body: "#{cur}\n", content_type: 'text/plain')
end

unless %w(americano americano.home.her americano.local).include?(Socket.gethostname)
  puts "This host (#{Socket.gethostname}) is not expected to run"
  loop { sleep 3600 }
end

profile = Aws::SharedCredentials.new(profile_name: AWS_PROFILE)

@sqs = Aws::SQS::Client.new(credentials: profile, region: AWS_REGION)
@s3 = Aws::S3::Client.new(credentials: profile, region: AWS_REGION)

@logs_lock = Mutex.new
@logs = Aws::CloudWatchLogs::Client.new(credentials: profile, region: AWS_REGION)
@logs_sequence_token = latest_sequence_token

url = @sqs.get_queue_url(queue_name: SQS_QUEUE_NAME).queue_url

Thread.new do
  poller = Aws::SQS::QueuePoller.new(url, client: @sqs)
  poller.poll do |msg|
    puts "Received a message: #{msg.inspect}"
    begin
      if nw_locate == 'home'
        puts "Waking up..."
        track = wakeup!(run_id: msg.message_id)
        publish_log(msg.message_id, {kind: 'ack', message_id: msg.message_id, track: track})
      else
        puts "Not in home, skipping"
        publish_log(msg.message_id, {kind: 'skip', message_id: msg.message_id, reason: 'agent not in home'})
      end
    rescue Exception => e
      warn "Oops, raised an error: #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
      publish_log(msg.message_id, {kind: 'error', message_id: msg.message_id, error: e.class.inspect})
      raise
    end
  end
end.abort_on_exception = true

loop do
  begin
    update_current_track
    sleep 60
  rescue Interrupt
    break
  rescue Exception => e
    warn "oops: #{e.inspect}"
    sleep 60
  end
end
