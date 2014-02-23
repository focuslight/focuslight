require 'dotenv'
Dotenv.load
require "focuslight/version"
require "focuslight/config"
require 'logger'
$logger = Logger.new('log/application.log')
$logger.level = Focuslight::Config.get(:log_level)

module Focuslight
end
