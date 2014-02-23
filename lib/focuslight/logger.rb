require 'logger'
require "focuslight/config"

module Focuslight
  module Logger
    def self.included(klass)
      # To define logger *class* method
      klass.extend(self)
    end

    # for test
    def logger=(logger)
      Focuslight.logger = logger
    end

    def logger
      Focuslight.logger
    end
  end

  # for test
  def self.logger=(logger)
    @logger = logger
  end

  def self.logger
    return @logger if @logger

    log_path = Focuslight::Config.get(:log_path)
    log_level = Focuslight::Config.get(:log_level)
    # NOTE: Please note that ruby 2.0.0's Logger has a problem on log rotation.
    # Update to ruby 2.1.0. See https://github.com/ruby/ruby/pull/428 for details.
    log_shift_age = Focuslight::Config.get(:log_shift_age)
    log_shift_size = Focuslight::Config.get(:log_shift_size)
    @logger = ::Logger.new(log_path, log_shift_age, log_shift_size)
    @logger.level = log_level
    @logger
  end
end
