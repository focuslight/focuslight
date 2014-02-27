require "bundler/gem_tasks"
require "octorelease"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-c", "-f progress"] # '--format specdoc'
  t.pattern = 'spec/**/*_spec.rb'
end

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dotenv/tasks'

task :console => :dotenv do
  require "focuslight/init"
  require 'irb'
  # require 'irb/completion'
  ARGV.clear
  IRB.start
end
task :c => :console

task :test => :spec
task :default => :spec
