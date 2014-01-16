require "rubygems"
require "sinatra"

require File.expand_path '../lib/focuslight/web.rb', __FILE__

run Focuslight::Web
