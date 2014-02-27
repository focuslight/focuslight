require 'spec_helper'
require 'focuslight/cli'

describe Focuslight::CLI do
  let(:cli) { Focuslight::CLI.new }

  context "#new" do
    before { cli.invoke(:new) }
    it {
      expect(Dir.exists?(Focuslight::CLI::BASE_DIR)).to be_true
      expect(Dir.exists?(Focuslight::CLI::LOG_DIR)).to be_true
      expect(File.read(Focuslight::CLI::ENV_FILE)).to eql(Focuslight::CLI::DEFAULT_DOTENV)
      expect(File.read(Focuslight::CLI::PROCFILE)).to eql(Focuslight::CLI::DEFAULT_PROCFILE)
      expect(File.read(Focuslight::CLI::CONFIGRU_FILE)).to eql(Focuslight::CLI::DEFAULT_CONFIGRU)
    }
    after { FileUtils.remove_dir(Focuslight::CLI::BASE_DIR) }
  end

  context "#init" do
    before {
      cli.invoke(:new)
      Dir.chdir(Focuslight::CLI::BASE_DIR) {|path|
        cli.invoke(:init)
      }
    }
    it { expect(Dir.exists?(Focuslight::CLI::DATA_DIR)).to be_true }
    after { FileUtils.remove_dir(Focuslight::CLI::BASE_DIR) }
  end
end
