require "focuslight"
require "focuslight/config"
require "focuslight/data"
require "focuslight/rrd"

class Focuslight::Worker
  DEFAULT_RRD_UPDATE_WORKER_INTERVAL = 300

  WORKER_TARGET_VALUES = [:normal, :short]

  attr_reader :interval

  def self.run(opts)
    Focuslight::Worker.new(opts).run
  end

  def initialize(opts)
    @interval = opts[:interval] || DEFAULT_RRD_UPDATE_INTERVAL
    @target = opts[:target] || :normal
    raise ArgumentError, "invalid worker target #{@target}" unless WORKER_TARGET_VALUES.include?(@target)

    # @datadir = Focuslight::Config.get(:datadir)
    #TODO: @datastore = ?

    @signals = []
  end

  def graphs
    #TODO: TODO: get graph objects
  end

  def update_next!(now)
    now = Time.now
    @next_time = now - ( now.to_i % @interval ) + @interval
  end

  def run
    Signal.trap(:INT){  @signals << :INT }
    Signal.trap(:HUP){  @signals << :HUP }
    Signal.trap(:TERM){ @signals << :TERM }
    Signal.trap(:PIPE, "IGNORE")

    update_next!

    childpid = nil
    while sleep(0.5) do
      if childpid
        begin
          pid = waitpid(childpid, Process::WNOHANG)
          if pid
            #TODO: $? (Process::Status object)
            childpid = nil
          end
        rescue Errno::ECHILD
          childpid = nil
        end
      end

      unless @signals.empty?
        # signal received
        break
      end

      next if Time.now < next_time
      update_next!

      if pid
        # TODO: previous radar exists, skip
        next
      end

      childpid = fork do
        graphs().each do |graph|
          update_rrd(graph_data(graph.id), :target => @target)
        end
      end
    end

    if childpid
      # waiting for updater child process
      begin
        waitpid childpid
      rescue Errno::ECHILD
        # ignore
      end
    end
  end
end
