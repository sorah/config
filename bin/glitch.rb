#!/usr/bin/env macruby
#
# MacRubyで画面グリッチをフルスクリーン表示する
#
#   http://twitter.com/negipo/status/67572370247913473
#
# ## Usage
#
#    ./glitch.rb
#
#    # gif flavor
#    % ./glitch.rb --flavors gif
#
#    % ./glitch.rb --flavors gif,jpeg
#
#    # command line help
#    % ./glitch.rb -h
#
# * より高速に楽しみたい場合は
#
#    % macrubyc glitch.rb -o glitch
#    % ./glitch
#
# * 常用したい場合は (control_towerが必要です)
#
#    # Start glitch server.
#    % ./glitch.rb --server
#
#    # Glitch all screens.
#    % curl http://localhost:9999/screens
#
#    # Glitch selected screen.
#    % curl http://localhost:9999/screens/0
#
#    # Passing parameters.
#    % curl http://localhost:9999/screens?flavors=png,gif
#
# Tested with MacRuby-0.10
#
# ## TODO
#
#   * png flavorが遅い。
#   * スクリーン指定した場合にグリッチさせないスクリーンが真っ暗になる。
#     グリッチさせながら作業できないので困る。
#   * 遅い(https://twitter.com/todesking/status/278393897238003712)
#
# ## Changes
#
# 2012-12-12 @1VQ9
#
#   * --serverオプション追加
#   * glitch終わった後にフォーカス外すようにした。
#
# 2012-02-23 @1VQ9
#
#   * png flavor追加
#
# 2012-02-01 @1VQ9
#
#   * デフォルトで全ての画面をグリッチするようにした
#
# 2012-01-30 @1VQ9
#
#   * flavor追加
#   * 中間ファイル出すのやめた
#
# ## References:
#
#   http://d.hatena.ne.jp/Watson/20100413/1271109590
#   http://www.cocoadev.com/index.pl?CGImageRef
#   http://d.hatena.ne.jp/Watson/20100823/1282543331
#   http://purigen.seesaa.net/article/137382769.html # how to access binary data in CGImageRef
#   http://www.jarchive.org/akami/aka018.html (glitchpng.rb)
#

require 'optparse'
require 'zlib'
begin
  require 'rubygems'
  require 'control_tower'
  require 'rack'
rescue LoadError
  HAS_CTRL_TWR = false
else
  HAS_CTRL_TWR = true
end

framework 'Cocoa'
framework 'ApplicationServices'
framework 'CoreGraphics'

module Glitch

  class Server
    attr_reader :options

    def initialize(options)
      [:screen, :output, :server].each do |k|
        options.delete k
      end
      @options = options
    end

    def applicationDidFinishLaunching(notification)
      server_opts = {:host => "localhost",
                     :port => 9999,
                     :concurrent => true}
      queue = Dispatch::Queue.concurrent(:default)
      queue.async {
        ControlTower::Server.new(self,server_opts).start
      }
      NSLog("Glitch server started. http://#{server_opts[:host]}:#{server_opts[:port]}")
      NSLog("Example: http://#{server_opts[:host]}:#{server_opts[:port]}/screens")
    end

    def call(env)
      req = Rack::Request.new env
      glitch_opts = normalize_options(req.params)
      code, response = 200, ""
      NSLog("#{req.request_method}: #{req.path_info}")

      if req.path_info =~ /\/screens\/{0,1}$/
        glitch_opts[:screen] = :all
        NSLog("glitch: #{glitch_opts.inspect}")
        Glitch::Screen.glitch glitch_opts
        response = "Glitched."
      elsif req.path_info =~ /\/screens\/(\d+?)$/
        glitch_opts[:screen] = $1.to_i
        NSLog("glitch: #{glitch_opts.inspect}")
        Glitch::Screen.glitch glitch_opts
        response = "Screen #{glitch_opts[:screen]} Glitched."
      else
        NSLog(req.fullpath)
        code     = 404
        response = "Try /screens/ or /screens/0 "
      end
      # Return Response.
      [
        code,
        {"Content-Type" => "text/html;charset=utf-8"},
        response
      ]
    rescue => e
      puts e
      puts e.backtrace
      [500, {"Content-Type" => "text/html"}, "Error."]
    end

    protected

    def normalize_options(params)
      opt = @options.merge Hash[params.map{|k, v|
        if k == 'flavors'
          v = v.split(',')
        end
        [k.to_sym, v]
      }]
    end

  end

  # == Glitch::Flavor
  #
  module Flavor
    class << self
      def exists? name
        class_name = camelcase name.to_s
        exist = true
        begin
          self.const_get class_name
        rescue NameError
          exist = false
        end
        return exist
      end

      def get name
        klass = self.const_get camelcase(name.to_s)
        klass.new
      end

      def camelcase string
        string.gsub(/(^\w|_\w)/){|s| s.gsub('_', '').upcase }
      end
    end

    # == Glitch::Flavor::Base
    #
    class Base
      def bitmap_image data
        NSBitmapImageRep.imageRepWithData data
      end
    end

    # == Glitch::Flavor::Jpeg
    #
    class Jpeg < Base
      # in     : NSBitmapImageRep
      # glitch : NSData ( by representationUsingType )
      # out    : NSBitmapImageRep ( by imageRepWithData )
      def glitch bitmap, finalize=false
        data   = bitmap.representationUsingType(NSJPEGFileType, properties:nil)
        100.times.each do
          pos = (rand data.length).to_i
          data.bytes[pos] = 0
        end
        if finalize
          data
        else
          bitmap_image(data)
        end
      end
    end

    # == Glitch::Flavor::Png
    #
    class Png < Base
      # in     : NSBitmapImageRep
      # glitch : NSData ( by representationUsingType )
      # out    : NSBitmapImageRep ( by imageRepWithData )
      def glitch bitmap, finalize=false
        data   = bitmap.representationUsingType(NSPNGFileType, properties:nil)

        # Convert raw bytes to glitchable bytes
        #   header    (png-header, image-header)
        #   raw_image (decompressed idat)
        #   iend      (IEND)
        header, raw_image, iend = extract_image data

        # Glitch
        glitched_image_bytes = glitch_image raw_image

        # Reconstruct image data
        glitched_nsdata = build_image header, glitched_image_bytes, iend

        if finalize
          glitched_nsdata
        else
          bitmap_image(glitched_nsdata)
        end
      end

      def glitch_image image_bytes
        # PNG filter method 0 defines five basic filter types:
        #
        #   http://www.libpng.org/pub/png/spec/1.2/PNG-Filters.html
        #
        #    Type    Name
        #
        #    0       None
        #    1       Sub
        #    2       Up
        #    3       Average
        #    4       Paeth
        #
        (0..(image_bytes.size - 1)).each do |i|
          #if (rand(10) % 6) > 2 && image_bytes[i] == 2
          #  image_bytes[i] = rand(5)
          if image_bytes[i] > 10 && image_bytes[i] < 17 && (rand(10) % 6) > 4
            image_bytes[i] = rand(255)
          end
        end
        image_bytes
      end

      protected

      def build_image head, image_bytes, iend
        compressed_image = Zlib::Deflate.deflate(image_bytes.pack('C*'))
        image_size       = [compressed_image.size].pack('N').unpack('C*')
        image_crc        = [Zlib.crc32(compressed_image, Zlib.crc32('IDAT'))].pack('N').unpack('C*')
        png_byte_array   = head + image_size + 'IDAT'.unpack('C*') + compressed_image.unpack('C*') + image_crc + iend
        buffer = Pointer.new(:char, png_byte_array.size)
        png_byte_array.each_with_index do |b, i|
          buffer[i] = b
        end
        NSData.alloc.initWithBytes(buffer, length:png_byte_array.size)
      end

      def extract_image nsdata
        buffer = {
          :head   => Pointer.new(:char, 8),
          :length => Pointer.new(:char, 4),
          :type   => Pointer.new(:char, 4),
          :crc    => Pointer.new(:char, 4)
        }
        byte_array = {
          :head   => [],
          :idat   => [],
          :ihdr   => [],
          :iccp   => [],
          :iend   => []
        }

        save_crc = nil
        state    = :length
        position = 8       # Skip PNG header

        # Get PNG header
        nsdata.getBytes(buffer[:head], range:nsrange(0, 8))
        byte_array[:head].concat pointer_to_array(buffer[:head])

        # Read chunks
        loop do
          break if position >= nsdata.length
          case state
          when :length
            nsdata.getBytes(buffer[:length], range:nsrange(position, 4))
            position += 4
            state    = :type
          when :type
            nsdata.getBytes(buffer[:type], range:nsrange(position, 4))
            position += 4
            state    = :data
          when :data
            data_length = pointer_to_uint32 buffer[:length]
            data_type   = pointer_to_s buffer[:type]

            if data_length > 0
              data_buffer = Pointer.new(:char, data_length)
              nsdata.getBytes(data_buffer, range:nsrange(position, data_length))

              case data_type
              when 'IDAT'
                byte_array[:idat].concat pointer_to_array(data_buffer)
              when 'IHDR'
                byte_array[:head].concat pointer_to_array(buffer[:length])
                byte_array[:head].concat pointer_to_array(buffer[:type])
                byte_array[:head].concat pointer_to_array(data_buffer)
                save_crc = :head
              when 'iCCP'
                byte_array[:iccp].concat pointer_to_array(buffer[:length])
                byte_array[:iccp].concat pointer_to_array(buffer[:type])
                byte_array[:iccp].concat pointer_to_array(data_buffer)
                save_crc = :iccp
              end
            elsif data_type == 'IEND'
              byte_array[:iend].concat pointer_to_array(buffer[:length])
              byte_array[:iend].concat pointer_to_array(buffer[:type])
              save_crc = :iend
            end
            position += data_length
            state = :crc
          when :crc
            if !save_crc.nil?
              nsdata.getBytes(buffer[:crc], range:nsrange(position, 4))
              byte_array[save_crc].concat pointer_to_array(buffer[:crc])
              save_crc = nil
            end
            position += 4
            state = :length
          end
        end

        # Decompress IDAT
        raw_image = Zlib::Inflate.new.inflate(byte_array[:idat].pack('C*')).unpack('C*')

        return [byte_array[:head], raw_image, byte_array[:iend]]
      end

      def pointer_to_uint32 pointer
        string = ''
        string += [pointer[0]].pack('C')
        string += [pointer[1]].pack('C')
        string += [pointer[2]].pack('C')
        string += [pointer[3]].pack('C')
        string.unpack('N').first.to_i
      end

      def pointer_to_array(pointer, cast=nil)
        array = []
        pos   = 0
        loop do
          begin
            array << pointer[pos]
          rescue
            break
          end
          pos += 1
        end
        array
      end

      def pointer_to_s(pointer)
        pointer_to_array(pointer).pack('C*').to_s
      end

      def nsrange(range_or_start, len=nil)
        ns = NSRange.new
        if range_or_start.kind_of? Range
          ns.location = range_or_start.first
          ns.length = range_or_start.end - range_or_start.first + 1
        elsif range_or_start.kind_of? Fixnum
          ns.location = range_or_start
          ns.length   = len
        end
        ns
      end
    end

    # == Glitch::Flavor::Tiff
    #
    class Tiff < Base
    end

    # == Glitch::Flavor::Gif
    #
    class Gif < Base
      def glitch bitmap, finalize=false
      data   = bitmap.representationUsingType(NSGIFFileType, properties:nil)
      10.times.each do
        pos = (rand data.length).to_i
        data.bytes[pos] = 0
      end
      if finalize
        data
      else
        bitmap_image(data)
      end
      end
    end

    # ちゃんとグリッチできてない
    #
    # class Bmp < Base
    #   def glitch bitmap, finalize=false
    #     data   = bitmap.representationUsingType(NSBMPFileType, properties:nil)
    #     1000.times.each do
    #       pos = (rand data.length).to_i
    #     end
    #     if finalize then data else bitmap_image data end
    #   end
    # end
  end

  # == Glitch::Screen
  #
  class Screen
    attr_accessor :number, :rect, :window

    def self.glitch options={}
      screens = []
      if options[:screen] == :all
        NSScreen.screens.length.times do |i|
          screens << new(i)
        end
      else
        screens << new(options[:screen])
      end

      screens.each do |screen|
        screen.capture
      end

      screens.each do |screen|
        screen.install_flavors options[:flavors]
        screen.show if options[:show_installation]
        sleep options[:interval] if options[:interval]
      end

      (options[:loop] || 1).times do
        screens.each do |screen|
          screen.show
          screen.write if options[:output]
        end
        sleep options[:interval] if options[:interval]
      end

      sleep options[:time] if options[:time]
    end

    def initialize screen_number
      @number = screen_number || 0
      @flavors = []
      init_window
    end

    def capture
      image = CGWindowListCreateImage(NSRectToCGRect(@rect),
                                      KCGWindowListOptionOnScreenOnly,
                                      KCGNullWindowID,
                                      KCGWindowImageDefault)
      bitmap = NSBitmapImageRep.alloc.initWithCGImage(image)
      @capture = bitmap
      return bitmap
    end

    def install_flavors flavors
      flavors.each do |name|
        flavor = if Flavor.exists? name
                   Flavor.get name
                 else
                   raise "No such flavor: #{name}"
                 end
        self << flavor
      end
    end

    def << flavor
      @flavors << flavor
    end

    def show_image(image)
        image_view = NSImageView.alloc.initWithFrame @rect
        image_view.setImage image
        image_view.enterFullScreenMode @window.screen, withOptions:nil
        image_view
    end

    def test(image)
      NSLog("Glitch::Screen#show")
    end

    # NSApplicationで使う場合のメソッドとスクリプトで使う場合のメソッドは分けた方がよさそう。
    def show
      generate_glitched_data
      image = NSImage.alloc.initWithData @glitched_data
      NSLog("Glitch::Screen#show")
      if !image.nil? && image.isValid
        if NSThread.isMainThread
          NSLog("This is main thread")
          image_view = self.show_image(image)
          @window.orderFrontRegardless
          @window.setContentView image_view
        else
          NSLog("This is not main thread")
          image_view = self.show_image(image)
          main = Dispatch::Queue.main
          main.after(1) {
            image_view.exitFullScreenModeWithOptions nil
            @window.close
            NSApplication.sharedApplication.hide nil
          }
        end
      else
        raise "Failed to load image."
      end
    end

    def write
      image = NSBitmapImageRep.imageRepWithData @glitched_data
      raise "Failed to load image." if image.nil?
      data = image.representationUsingType(NSPNGFileType, properties:nil)
      data.writeToFile "#{ENV['HOME']}/Desktop/GlitchedCapture_#{@number}.png", atomically:false
    end

    protected

    def init_window
      @rect   = NSScreen.screens[@number].frame()
      @window = NSWindow.alloc.initWithContentRect(@rect,
                                                   styleMask:NSBorderlessWindowMask,
                                                   backing:NSBackingStoreBuffered,
                                                   defer:false)
      @window.setBackgroundColor(NSColor.clearColor)
      @window.setOpaque false
    end

    def generate_glitched_data
      @glitched_data = @capture # initialize
      @flavors.each_with_index do |f, i|
        @glitched_data = f.glitch @glitched_data, (i == (@flavors.length - 1))
      end
    end

  end
end

# main program


app = NSApplication.sharedApplication

options = {
  :flavors     => ['jpeg'],
  :screen     => :all,
  :time       => 2,
  :output     => false,
  :server     => false
}

OptionParser.new do |opts|
  opts.banner = "Usage: glitch.rb [options]"
  opts.separator "Options:"

  opts.on("--server", TrueClass, "Start glitch server.") do |v|
    options[:server] = v
  end

  opts.on("-f", "--flavors x,y,z", Array,
          "Specify flavor of glitch.To use multiple flavors, separate by comma."
         ) do |list|
    options[:flavors] = list
  end

  opts.on("-s", "--screen N", Numeric,
          "Number of a target screen. (Default is all screens)") do |number|
    options[:screen] = number
  end

  opts.on("-o", "--output", String) do |v|
    options[:output] = v
  end

  opts.on("-t", "--time N", Float,"Time to sleep (sec)") do |v|
    options[:time] = v
  end

  opts.on("-l", "--loop N", Numeric, "Loop N times") do |v|
    options[:loop] = v
  end

  opts.on("-i", "--interval N", Numeric, "interval in loop") do |v|
    options[:interval] = v
  end

  opts.on("-F", "--show-flavors-installation", "Show process of installation.") do
    options[:show_installation] = true
  end

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
end.parse!

if options[:server]
  if HAS_CTRL_TWR
    srv = Glitch::Server.new options
    app.setDelegate(srv)
    app.run
  else
    abort "Server mode requires control_tower. To install it, type 'macgem install control_tower'"
  end
else
  Glitch::Screen.glitch options
end
