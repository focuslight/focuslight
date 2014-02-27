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
  PROCFILE = File.join(BASE_DIR, "Procfile")
  CONFIGRU_FILE = File.join(BASE_DIR, "config.ru")

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

  DEFAULT_PROCFILE =<<-EOS
web: unicorn -E production -p $PORT -o $HOST
worker1: focuslight longer
worker2: focuslight shorter
EOS

  DEFAULT_CONFIGRU =<<-EOS
require "rubygems"
require "sinatra"
require "focuslight"
require "focuslight/web"

run Focuslight::Web
EOS

  default_command :start

  desc "new", "Creates focuslight resource directory"
  def new
    FileUtils.mkdir_p(LOG_DIR)
    File.write ENV_FILE, DEFAULT_DOTENV
    File.write PROCFILE, DEFAULT_PROCFILE
    File.write CONFIGRU_FILE, DEFAULT_CONFIGRU
  end

  desc "init", "Creates database schema"
  def init
    Dotenv.load
    require "focuslight/init"
    Focuslight::Init.run
  end

  desc "start", "Sartup focuslight"
  def start
    Dotenv.load
    require "foreman/cli"
    Foreman::CLI.new.invoke(:start, [], {})
  end

  desc "longer", "Startup focuslight longer worker"
  def longer
    Dotenv.load
    require "focuslight/worker"
    Focuslight::Worker.run(interval: 300, target: :normal)
  end

  desc "shorter", "Startup focuslight shorter worker"
  def shorter
    Dotenv.load
    require "focuslight/worker"
    Focuslight::Worker.run(interval: 60, target: :short)
  end
end
