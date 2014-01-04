require "focuslight/web"
Focuslight::Web.run! :host => ENV['HOST'], :port => ENV['PORT']
