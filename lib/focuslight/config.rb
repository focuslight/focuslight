require "focuslight"

module Focuslight::Config
  DEFAULT_DATADIR = File.expand_path('data', "#{__dir__}/../..")
  DEFAULT_LOG_PATH = File.expand_path('log/application.log', "#{__dir__}/../..")
  CONFIG = {
    datadir: ENV.fetch('DATADIR', DEFAULT_DATADIR),
    float_support: ENV.fetch('FLOAT_SUPPORT', false),
    dburl: ENV.fetch('DBURL', 'sqlite://data/gforecast.db'),
    log_path: ENV.fetch('LOG_PATH', DEFAULT_LOG_PATH),
    log_level: ENV.fetch('LOG_LEVEL', 'info'),
    log_shift_age: ENV.fetch('LOG_SHIFT_AGE', '0'),
    log_shift_size: ENV.fetch('LOG_SHIFT_SIZE', '1048576'),
  }

  def self.get(name)
    unless CONFIG.has_key?(name)
      raise ArgumentError, 'unknown configuration keyword'
    end
    CONFIG[name]
  end
end
