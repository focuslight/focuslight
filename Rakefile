require "bundler/gem_tasks"

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dotenv/tasks'
require "focuslight/worker"

task :init => :dotenv do
  Focuslight::Init.run
end

task :longer => :dotenv do
  Focuslight::Worker.run(interval: 300, target: :normal)
end

task :shorter => :dotenv do
  Focuslight::Worker.run(interval: 60, target: :short)
end
