require 'dotenv'
Dotenv.load
require "focuslight/version"
require "focuslight/config"
require 'logger'
# NOTE: Please note that ruby 2.0.0's Logger has a problem on log rotation.
# Update to ruby 2.1.0 to use log rotation. See https://github.com/ruby/ruby/pull/428 for details.
$logger = Logger.new('log/application.log')
$logger.level = Focuslight::Config.get(:log_level)

module Focuslight
end
