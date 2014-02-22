require "bundler/gem_tasks"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-c", "-f progress"] # '--format specdoc'
  t.pattern = 'spec/**/*_spec.rb'
end

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dotenv/tasks'
require "focuslight/worker"

task :init => :dotenv do
  require "focuslight/init"
  Focuslight::Init.run
end

task :console => :dotenv do
  require "focuslight/init"
  require 'irb'
  # require 'irb/completion'
  ARGV.clear
  IRB.start
end
task :c => :console

task :longer => :dotenv do
  Focuslight::Worker.run(interval: 300, target: :normal)
end

task :shorter => :dotenv do
  Focuslight::Worker.run(interval: 60, target: :short)
end

task :test => :spec
task :default => :spec
