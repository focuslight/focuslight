require "focuslight"
require "focuslight/config"
require "sinatra/base"

class Focuslight::Web < Sinatra::Base
  set :dump_errors, true
  set :public_folder, File.join(__dir__, '..', '..', 'public')
  set :views,         File.join(__dir__, '..', '..', 'views')

  configure do
    # TODO: check ENV['DATADIR'] and mkdir if not exists
  end

  helpers do
    def help(hoge)
    end
  end

  get '/'
end
