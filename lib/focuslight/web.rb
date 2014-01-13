require "focuslight"
require "focuslight/config"
require "focuslight/data"
require "focuslight/rrd"

require "focuslight/validator"

require "time"
require "cgi"

require "sinatra/base"
require "sinatra/json"
require "sinatra/url_for"

class Focuslight::Web < Sinatra::Base
  set :dump_errors, true
  set :public_folder, File.join(__dir__, '..', '..', 'public')
  set :views,         File.join(__dir__, '..', '..', 'views')

  def self.rule(*args)
    Focuslight::Validator.rule(*args)
  end

  configure do
    datadir = Focuslight::Config.get(:datadir)
    unless Dir.exists?(datadir)
      Dir.mkdir(datadir)
    end
  end

  helpers Sinatra::JSON
  helpers Sinatra::UrlForHelper
  helpers do
    def urlencode(str)
      CGI.escape(str)
    end

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
      parts = [:service, :section].map{|s| urlencode(graph.send(s))}
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
                if params.has_key?(:graph_id)
                  data().get_by_id(params[:graph_id])
                else
                  data().get(params[:service_name], params[:section_name], params[:graph_name])
                end
              when :complex
                if params.has_key?(:complex_id)
                  data().get_complex_by_id(params[:complex_id])
                else
                  data().get_complex(params[:service_name], params[:section_name], params[:graph_name])
                end
              else
                raise "graph type is invalid: #{type}"
              end
      halt 404 unless graph
      request.stash[:graph] = graph
    end
  end

  get '/docs' do
    request.stash[:docs] = true
    erb :docs
  end

  get '/' do
    services = []
    data().get_services.each do |service|
      services << {:name => service, :sections => data().get_sections(service)}
    end
    erb :index, locals: { services: services }
  end

  get '/list/:service_name' do
    services = []
    sections = data().get_section(params[:service_name])
    services << { name: params[:service_name], sections: sections }
    erb :index, :locals => { services: services }
  end

  not_specified_or_not_whitespece = {
    rule: rule(:lambda, ->(v){ v.nil? || !v.strip.empty? }, "invalid name(whitespace only)", ->(v){ v && v.strip })
  }
  graph_view_spec = {
    service_name: not_specified_or_not_whitespece,
    section_name: not_specified_or_not_whitespece,
    graph_name:   not_specified_or_not_whitespece,
    t: { default: 'd', rule: rule(:choice, 'd', 'h', 'm', 'sh', 'sd') }
  }

  get '/list/:service_name/:section_name' do
    req_params = validate(params, graph_view_spec)
    graphs = data().get_graphs(req_params[:service_name], req_params[:section_name])
    erb :list, locals: { params: req_params.hash, graphs: graphs }
  end

  get '/view_graph/:service_name/:section_name/:graph_name', :graph => :simple do
    req_params = validate(params, graph_browse_term_spec)
    erb :view_graph, locals: { params: req_params.hash, graphs: [ request.stash[:graph] ] }
  end

  get '/view_complex/:service_name/:section_name/:graph_name', :graph => :complex do
    req_params = validate(params, graph_browse_term_spec)
    erb :view_graph, locals: { params: req_params.hash, graphs: [ request.stash[:graph] ], view_complex: true }
  end

  get '/edit/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  post '/edit/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  post '/delete/:service_name/:section_name' do
    #TODO
  end

  post '/delete/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  get '/add_complex' do
    graphs = data().get_all_graph_name
    erb :add_complex, locals: {graphs: graphs} #TODO: disable_subtract
  end

  complex_graph_request_spec_generator = ->(type2s_num){
    {
      service_name: { rule: rule(:not_blank) },
      section_name: { rule: rule(:not_blank) },
      graph_name:   { rule: rule(:not_blank) },
      description:  { default: '' },
      sumup: { rule: [ rule(:not_blank), rule(:int_range, 0..1) ] },
      sort:  { rule: [ rule(:not_blank), rule(:int_range, 0..19) ] },
      'type-1'.to_sym =>  { rule: [ rule(:not_blank), rule(:choice, 'AREA', 'LINE1', 'LINE2') ] },
      'path-1'.to_sym =>  { rule: [ rule(:not_blank), rule(:natural) ] },
      'gmode-1'.to_sym => { rule: [ rule(:not_blank), rule(:choice, gmode_choice()) ] },
      'type-2'.to_sym => {
        array: true, size: (type2s_num..type2s_num),
        rule: [ rule(:not_blank), rule(:choice, 'AREA', 'LINE1', 'LINE2') ],
      },
      'path-2'.to_sym => {
        array: true, size: (type2s_num..type2s_num),
        rule: [ rule(:not_blank), rule(:natural) ],
      },
      'gmode-2'.to_sym => {
        array: true, size: (type2s_num..type2s_num),
        rule: [ rule(:not_blank), rule(:choice, gmode_choice()) ],
      },
      'stack-2'.to_sym => {
        array: true, size: (type2s_num..type2s_num),
        rule: [ rule(:not_blank), rule(:bool) ],
      },
    }
  }

  post '/add_complex' do
    type2s = params['type-2'.to_sym]
    type2s_num = type2s && (! type2s.empty?) ? type2s.size : 1

    specs = complex_graph_request_spec_generator.(type2s_num)
    additional = {
      [:service_name, :section_name, :graph_name] => {
        rule: rule(:lambda, ->(service,section,graph){ data().get_complex(service,section,graph).nil? })
      },
    }
    specs.update(additional)
    req_params = validate(params, request_param_specs)

    if req_params.has_error?
      json({error: 1, messages: req_params.errors})
    else
      data().create_complex(req_params[:service_name], req_params[:section_name], req_params[:graph_name], req_params.hash)
      created_path = "/list/%s/%s/%s" % [:service_name,:section_name,:graph_name].map{|s| urlencode(req_params[s])}
      json({error: 0, location: url_for(created_path)})
    end
  end

  get '/edit_complex/:complex_id', :graph => :complex do
    graphs = data().get_all_graph_name
    render :edit_complex, locals: {graphs: graphs} #TODO: disable_subtract
  end

  post '/edit_complex/:complex_id', :graph => :complex do
    type2s = params['type-2'.to_sym]
    type2s_num = type2s && (! type2s.empty?) ? type2s.size : 1

    specs = complex_graph_request_spec_generator.(type2s_num)
    current_graph_id = request.stash[:graph].id
    additional = {
      [:service_name, :section_name, :graph_name] => {
        rule: rule(:lambda, ->(service,section,graph){
            graph = data().get_complex(service,section,graph)
            graph.nil? || graph.id == current_graph_id.id
          })
      },
    }
    specs.update(additional)
    req_params = validate(params, request_param_specs)

    if req_params.has_error?
      json({error: 1, messages: req_params.errors})
    else
      data().update_complex(request.stash[:graph].id, req_params.hash)
      created_path = "/list/%s/%s/%s" % [:service_name,:section_name,:graph_name].map{|s| urlencode(req_params[s])}
      json({error: 0, location: url_for(created_path)})
    end
  end

  post '/delete_complex/:complex_id', :graph => :complex do
    delete(request.stash[:graph]).to_json
  end

  graph_rendering_request_spec_generator = ->(){
    {
      method: { rule: [ rule(:not_blank), rule(:choice, 'xport', 'graph') ] }, # TODO: 'summary' is not supported yet
      service_name: not_specified_or_not_whitespece,
      section_name: not_specified_or_not_whitespece,
      graph_name: not_specified_or_not_whitespece,
      complex: not_specified_or_not_whitespece,
      t: { default: 'd', rule: rule(:choice, 'd', 'h', 'm', 'sh', 'sd') },
      gmode: { default: 'gauge', rule: rule(:choice, gmode_choice()) },
      from: {
        default: (Time.now - 86400*8).strftime('%Y/%m/%d %T'),
        rule: rule(:lambda, ->(v){ Time.parse(v) rescue false }, "invalid time format"),
      },
      to: {
        default: Time.now.strftime('%Y/%m/%d %T'),
        rule: rule(:lambda, ->(v){ Time.parse(v) rescue false }, "invalid time format"),
      },
      width:  { default: '390', rule: rule(:natural) },
      height: { default: '110', rule: rule(:natural) },
      graphonly: { default: 'false', rule: rule(:bool) },
      logarithmic: { default: 'false', rule: rule(:bool) },
      background_color: { default: 'f3f3f3', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      canvas_color:     { default: 'ffffff', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      font_color:   { default: '000000', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      frame_color:  { default: '000000', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      axis_color:   { default: '000000', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      shadea_color: { default: 'cfcfcf', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      shadeb_color: { default: '9e9e9e', rule: rule(:regexp, /^[0-9a-f]{6}([0-9a-f]{2})?$/i) },
      border: { default: '3', rule: rule(:uint) },
      legend: { defualt: 'true', rule: rule(:bool) },
      notitle: { default: 'false', rule: rule(:bool) },
      xgrid: { default: '' },
      ygrid: { default: '' },
      upper_limit: { default: '' },
      lower_limit: { default: '' },
      rigid: { default: 'false', rule: rule(:bool) },
      sumup: { default: 'false', rule: rule(:bool) },
      step: { rule: rule(:lambda, ->(v){v.nil? || v =~ /^\d+$/}, "invalid integer (>= 0)", ->(v){v && v.to_i}) },
      cf: { default: 'AVERAGE', rule: rule(:choice, 'AVERAGE', 'MAX') }
    }
  }

  get '/complex/:method/:service_name/:section_name/:graph_name' do
    #TODO
  end

  get '/:method/:complex' do
    #TODO
  end

  get '/:method/:service_name/:section_name/:graph_name' do
    #TODO
  end

  get '/api/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  post '/api/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  #TODO graph4json
  #TODO graph4internal

  # alias to /api/:service_name/:section_name/:graph_name
  get '/json/graph/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  get '/json/complex/:service_name/:section_name/:graph_name', :graph => :complex do
    #TODO
  end

  # alias to /delete/:service_name/:section_name/:graph_name
  post '/json/delete/graph/:service_name/:section_name/:graph_name', :graph => :simple do
    #TODO
  end

  post '/json/delete/graph/:graph_id', :graph => :simple do
    #TODO
  end

  post '/json/delete/complex/:service_name/:section_name/:graph_name', :graph => :complex do
    #TODO
  end

  post '/json/delete/complex/:complex_id', :graph => :complex do
    #TODO
  end

  get '/json/graph/:graph_id', :graph => :simple do
    #TODO
  end

  get '/json/complex/:complex_id', :graph => :complex do
    #TODO
  end

  get '/json/list/graph' do
    #TODO
  end

  get '/json/list/complex' do
    #TODO
  end

  get '/json/list/all' do
    #TODO
  end

  # TODO in create/edit, validations about json object properties, sub graph id existense, ....
  post '/json/create/complex' do
    #TODO
  end

  # post '/json/edit/{type:(?:graph|complex)}/:id' => sub {
  post '/json/edit/:type/:id' do
    #TODO
  end
end
