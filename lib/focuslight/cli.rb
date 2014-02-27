require "fileutils"
require "dotenv"
require "thor"

require "focuslight"

class Focuslight::CLI < Thor
  BASE_DIR = File.join(Dir.pwd, "focuslight")
  DATA_DIR = File.join(BASE_DIR, "data")
  DBURL = "sqlite://#{File.join(DATA_DIR, "gforecast.db")}"
  LOG_DIR = File.join(BASE_DIR, "log")
  LOG_FILE = File.join(LOG_DIR, "application.log")
  ENV_FILE = File.join(BASE_DIR, ".env")

  DEFAULT_DOTENV =<<-EOS
DATADIR=#{DATA_DIR}
PORT=5125
HOST=0.0.0.0
# FRONT_PROXY
# ALLOW_FROM
# 1MIN_METRICS=n
FLOAT_SUPPORT=n # y
DBURL=#{DBURL}
# DBURL=mysql2://root:@localhost/focuslight
# RRDCACHED=n
# MOUNT=/
LOG_PATH=#{LOG_FILE}
LOG_LEVEL=warn
EOS

  default_command :start

  desc "new", "Creating focuslight resource directory"
  def new
    FileUtils.mkdir_p(LOG_DIR)
    File.write ENV_FILE, DEFAULT_DOTENV
  end

  desc "init", "Creating database schema"
  def init
    raise "Run `focuslight new` first" unless File.exist? ENV_FILE
    Dotenv.load ENV_FILE
    require "focuslight/init"
    Focuslight::Init.run
  end

  desc "start", "Sartup focuslight server"
  def start
    raise "Run `focuslight new` first" unless File.exist? ENV_FILE

    Dotenv.load ENV_FILE
    require "foreman/cli"
    procfile = File.expand_path("../../../Procfile-gem", __FILE__)
    Foreman::CLI.new.invoke(:start, [], procfile: procfile)
  end
end
