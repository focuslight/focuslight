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
    else
      raise ArgumentError, 'unknown configuration keyword'
    end
  end
end
