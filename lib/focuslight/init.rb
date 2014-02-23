require "focuslight"
require "focuslight/data"

module Focuslight::Init
  def self.run
    datadir = Focuslight::Config.get(:datadir)
    FileUtils.mkdir_p(datadir)
    data = Focuslight::Data.new
    data.create_tables
  end
end
