require "focuslight"

module Focuslight::Config
  DEFAULT_DATADIR = File.expand_path('data', "#{__dir__}/../..")
  DEFAULT_LOG_PATH = File.expand_path('log/application.log', "#{__dir__}/../..")

  def self.get(name)
    case name
    when :datadir
      ENV.fetch('DATADIR', DEFAULT_DATADIR)
    when :float_support
      ENV.fetch('FLOAT_SUPPORT', false)
    when :dburl
      ENV.fetch('DBURL', 'sqlite://data/gforecast.db')
    when :log_path
      case log_path = ENV.fetch('LOG_PATH', DEFAULT_LOG_PATH)
      when 'STDOUT'
        $stdout
      when 'STDERR'
        $stderr
      else
        log_path
      end
    when :log_level
      case log_level = ENV.fetch('LOG_LEVEL', 'info')
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
        raise ArgumentError, "invalid log_level #{log_level}"
      end
    when :log_shift_age
      case shift_age = ENV.fetch('LOG_SHIFT_AGE', '0')
      when /\d+/
        shift_age.to_i
      when 'daily'
        shift_age
      when 'weekly'
        shift_age
      when 'monthly'
        shift_age
      else
        raise ArgumentError, "invalid log_shift_age #{shift_age}"
      end
    when :log_shift_size
      ENV.fetch('LOG_SHIFT_SIZE', '1048576').to_i
    else
      raise ArgumentError, 'unknown configuration keyword'
    end
  end
end
