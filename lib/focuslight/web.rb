require "focuslight"
require "focuslight/config"
require "focuslight/data"
require "focuslight/rrd"

require "focuslight/validator"

require "cgi"

require "sinatra/base"
require 'sinatra/url_for'

class Focuslight::Web < Sinatra::Base
  set :dump_errors, true
  set :public_folder, File.join(__dir__, '..', '..', 'public')
  set :views,         File.join(__dir__, '..', '..', 'views')

  configure do
    datadir = Focuslight::Config.get(:datadir)
    unless Dir.exists?(datadir)
      Dir.mkdir(datadir)
    end
  end

  helpers Sinatra::UrlForHelper
  helpers do
    def validate(*args)
      Focuslight::Validator.validate(*args)
    end

    def rule(*args)
      Focuslight::Validator.rule(*args)
    end

    def data
      @data ||= Focuslight::Data.new #TODO mysql support
    end

    def number_type
      data().number_type
    end

    def rrd
      @rrd ||= Focuslight::RRD.new
    end

    def gmode_choice
      ['gauge', 'subtract'] #TODO: disable_subtract
    end

    def gmode_choice_edit_graph
      ['gauge', 'subtract', 'both'] #TODO: disable_subtract
    end

    # short interval update is always enabled in focuslight
    ## TODO: option to disable?

    def delete(graph)
      if graph.complex?
        data().remove_complex(graph.id)
      else
        rrd().remove(graph)
        data().remove(graph.id)
      end
      parts = [:service, :section].map{|s| CGI.escape(graph.send(s))}
      {error: 0, location: url_for("/list/%s/%s" % parts)}
    end
  end

  module Stash
    def stash
      @stash ||= []
    end
  end

  before { request.extend Stash }

  set(:graph) do |type|
    condition do
      graph = case type
              when :simple
                data().get(params[:service_name], params[:section_name], params[:graph_name])
              when :complex
                data().get_complex_by_id(params[:complex_id])
              else
                raise "graph type is invalid: #{type}"
              end
      halt 404 unless graph
      request.stash[:graph] = graph
    end
  end

  get '/' do
    services = []
    data().get_services.each do |service|
      services << {:name => service, :sections => data().get_sections(service)}
    end
    erb :index, locals: {services: services}
  end

  get '/docs' do
    # request.stash[:docs] = true #TODO: is this used anywhere?
    erb :docs
  end

  get '/add_complex' do
    graphs = data().get_all_graph_name
    erb :add_complex locals: {graphs: graphs} #TODO: disable_subtract
  end

  post '/add_complex' do
    type2s = params['type-2'.to_sym] #TODO: check whether type2s is Array for multi-value http request?
    type2s_num = type2s && (! type2s.empty?) ? type2s.size : 1

    req_params = validate(params, {
        service_name: { rule: [ rule(:not_blank) ] },
        section_name: { rule: [ rule(:not_blank) ] },
        graph_name: { rule: [ rule(:not_blank) ] },
        [:service_name, :section_name, :graph_name] => {
          rule: rule(:lambda, ->(service,section,graph){
              
              data().
  end

  get '/edit_complex/:complex_id', :graph => :complex do
    graphs = data().get_all_graph_name
    render :edit_complex, locals: {graphs: graphs} #TODO: disable_subtract
  end

  post '/delete_complex/:complex_id', :graph => :complex do
    delete(request.stash[:graph]).to_json
  end

end

