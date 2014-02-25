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
      ENV.fetch('LOG_PATH', DEFAULT_LOG_PATH)
    when :log_level
      ENV.fetch('LOG_LEVEL', 'info')
    when :log_shift_age
      ENV.fetch('LOG_SHIFT_AGE', '0')
    when :log_shift_size
      ENV.fetch('LOG_SHIFT_SIZE', '1048576')
    else
      raise ArgumentError, 'unknown configuration keyword'
    end
  end
end
