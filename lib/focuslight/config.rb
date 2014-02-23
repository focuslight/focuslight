require "focuslight"

module Focuslight::Config
  DEFAULT_DATADIR = File.join(__dir__, '..', '..', 'data')

  def self.get(name)
    case name
    when :datadir
      ENV.fetch('DATADIR', DEFAULT_DATADIR)
    when :float_support
      ENV.fetch('FLOAT_SUPPORT', false)
    when :dburl
      ENV.fetch('DBURL', 'sqlite://data/gforecast.db')
    when :log_level
      case ENV.fetch('LOG_LEVEL', 'info')
      when 'debug'
        Logger::DEBUG
      when 'info'
        Logger::INFO
      when 'warn'
        Logger::WARN
      when 'error'
        Logger::ERROR
      when 'fatal'
        Logger::FATAL
      else
        raise ArgumentError, 'unknown log_level'
      end
    else
      raise ArgumentError, 'unknown configuration keyword'
    end
  end
end
