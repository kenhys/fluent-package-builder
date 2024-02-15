require 'optparse'
module Fluent
  class ConflictDetector
    def self.linux?
      /linux/ === RUBY_PLATFORM
    end

    def self.under_systemd?(pid)
      pid == 1 or @pidmap[@pidmap[pid]] == 1
    end

    def self.running_fluentd_conf
      unless linux?
        return nil
      end

      @pidmap = {}
      IO.popen(["/usr/bin/ps", "-e", "-o", "uid,pid,ppid,cmd"]) do |_io|
        _io.readlines.each do |line|
          uid, pid, ppid, cmd = line.split(' ', 4)
          # skip current running process
          next if Process.pid == pid.to_i
          @pidmap[pid.to_i] = ppid.to_i
          if cmd and cmd.chomp.include?("fluentd") and under_systemd?(pid.to_i)
            # check only under systemd control
            File.open("/proc/#{pid.to_i}/environ") do |file|
              conf = file.read.split("\u0000").select { |entry| entry.include?("FLUENT_CONF") }
              return conf.first.split('=').last unless conf.empty?
            end
          end
        end
      end
      return nil
    end
  end

  class FakeOptionParser < OptionParser
    attr_reader :config_path
    def initialize
      @config_path = nil
      @opt =  OptionParser.new
      @opt.on('-c', '--config VAL') { |v|
        @config_path = v
      }
      @opt.on('-s', '--setup DIR')
      @opt.on('--dry-run')
      @opt.on('--show-plugin-config=PLUGIN')
      @opt.on('-p', '--plugin DIR')
      @opt.on('-I PATH')
      @opt.on('-r NAME')
      @opt.on('-d', '--daemon PIDFILE')
      @opt.on('--under-supervisor')
      @opt.on('--no-supervisor')
      @opt.on('--workers NUM')
      @opt.on('--user USER')
      @opt.on('--group GROUP')
      @opt.on('--umask UMASK')
      @opt.on('-o', '--log PATH')
      @opt.on('--log-rotate-age AGE')
      @opt.on('--log-rotate-size BYTES')
      @opt.on('--log-event-verbose')
      @opt.on('-i', '--inline-config CONFIG_STRING')
      @opt.on('-h', '--help')
    end

    def parse(argv)
      @opt.parse(argv)
    end

  end
end

begin
  running_fluentd_conf = Fluent::ConflictDetector.running_fluentd_conf
  unless Fluent::ConflictDetector.under_systemd?(Process.pid)
    if ENV["FLUENT_CONF"] and ENV["FLUENT_CONF"] == running_fluentd_conf
      # /usr/sbin/fluentd sets FLUENT_CONF=/etc/fluent/fluentd.conf by default
      # If it matches with running other instance, abort it
      puts "Error: can't start duplicate Fluentd instance with same #{ENV['FLUENT_CONF']}"
      exit 2
    else
      # /opt/fluent/bin/fluentd does not set FLUENT_CONF=/etc/fluent/fluentd.conf,
      # if -c option is given from command line, check and abort it.
      unless ARGV.empty?
        # preflight with dummy parser
        opt = Fluent::FakeOptionParser.new
        begin
          opt.parse(ARGV)
          if opt.config_path and opt.config_path == running_fluentd_conf
            puts "Error: can't start duplicate Fluentd instance with same #{running_fluentd_conf}"
            exit 2
          end
        rescue
        end
      end
    end
  end
rescue Errno::EACCES
  # e.g. unprivileged access error, can't detect duplicated instance from command line parameter.
rescue Errno::ENOENT
  # e.g. can't detect duplicated instance from ps.
end

