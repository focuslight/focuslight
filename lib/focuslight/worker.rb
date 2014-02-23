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

    @signals = []
  end

  def data
    @data ||= Focuslight::Data.new #TODO mysql support
  end

  def rrd
    @rrd ||= Focuslight::RRD.new
  end

  def update_next!
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
          if Process.waitpid(childpid, Process::WNOHANG)
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

      next if Time.now < @next_time
      update_next!

      if childpid
        # TODO: previous radar exists, skip
        next
      end

      childpid = fork do
        graphs = data().get_all_graph_all()
        graphs.each do |graph|
          # ToDo: logger.debug("[#{@target}] update #{graph.id}")
          rrd().update(graph, @target)
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
