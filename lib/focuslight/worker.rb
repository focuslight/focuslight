require "focuslight"
require "focuslight/config"
require "focuslight/logger"
require "focuslight/data"
require "focuslight/rrd"

class Focuslight::Worker
  include Focuslight::Logger

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
    @data ||= Focuslight::Data.new
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
    logger.info("[#{@target}] first updater start in #{@next_time}")

    childpid = nil
    while sleep(0.5) do
      if childpid
        begin
          if Process.waitpid(childpid, Process::WNOHANG)
            #TODO: $? (Process::Status object)
            logger.debug("[#{@target}] update finished pid: #{childpid}, code: #{$? >> 8}")
            logger.debug("[#{@target}] next rader start in #{@next_time}")
            childpid = nil
          end
        rescue Errno::ECHILD
          logger.warn("[#{@target}] no child process");
          childpid = nil
        end
      end

      unless @signals.empty?
        logger.warn("[#{@target}] signals_received: #{@signals.join(',')}")
        break
      end

      next if Time.now < @next_time
      update_next!
      logger.debug("[#{@target}] (#{@next_time}) updater start")

      if childpid
        logger.warn("[#{@target}] Previous radar exists, skipping this time")
        next
      end

      childpid = fork do
        graphs = data().get_all_graph_all()
        graphs.each do |graph|
          logger.debug("[#{@target}] update #{graph.id}")
          rrd().update(graph, @target)
        end
      end
    end

    if childpid
      logger.warn("[#{@target}] waiting for updater process finishing")
      begin
        waitpid childpid
      rescue Errno::ECHILD
        # ignore
      end
    end
  end
end
