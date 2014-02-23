require 'dotenv'
Dotenv.load
require "focuslight/version"
require 'logger'
$logger = Logger.new('log/application.log')

module Focuslight
end
