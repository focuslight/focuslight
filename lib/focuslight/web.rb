require "focuslight"
require "focuslight/config"
require "focuslight/data"
require "focuslight/rrd"

require "focuslight/validator"

require "time"
require "cgi"

require "sinatra/base"
require "sinatra/json"
require "erubis"

class Focuslight::Web < Sinatra::Base
  set :dump_errors, true
  set :public_folder, File.join(__dir__, '..', '..', 'public')
  set :views,         File.join(__dir__, '..', '..', 'view')
  set :erb, escape_html: true

  ### TODO: both of static method and helper method
  def self.rule(*args)
    Focuslight::Validator.rule(*args)
  end

  configure do
    datadir = Focuslight::Config.get(:datadir)
    FileUtils.mkdir_p(datadir)
  end

  helpers Sinatra::JSON
  helpers do
    def url_for(url_fragment, mode=nil, options = nil)
      if mode.is_a? Hash
        options = mode
        mode = nil
      end

      if mode.nil?
        mode = :path_only
      end

      mode = mode.to_sym unless mode.is_a? Symbol
      optstring = nil

      if options.is_a? Hash
        optstring = '?' + options.map { |k,v| "#{k}=#{URI.escape(v.to_s, /[^#{URI::PATTERN::UNRESERVED}]/)}" }.join('&')
      end

      case mode
      when :path_only
        base = request.script_name
      when :full
        scheme = request.scheme
        if (scheme == 'http' && request.port == 80 ||
            scheme == 'https' && request.port == 443)
          port = ""
        else
          port = ":#{request.port}"
        end
        base = "#{scheme}://#{request.host}#{port}#{request.script_name}"
      else
        raise TypeError, "Unknown url_for mode #{mode.inspect}"
      end
      "#{base}#{url_fragment}#{optstring}"
    end

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
      @data ||= Focuslight::Data.new
    end

    def number_type_rule
      type =  data().number_type
      if type == Float
        Focuslight::Validator.rule(:real)
      elsif type == Integer
        Focuslight::Validator.rule(:int)
      else
        raise "unknown number_type #{data().number_type}"
      end
    end

    def rrd
      @rrd ||= Focuslight::RRD.new
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

    def pathinfo(params)
      items = []
      return items unless params[:service_name]

      items << params[:service_name]
      return items unless params[:section_name]

      items << params[:section_name]
      return items unless params[:graph_name]

      items << params[:graph_name]
      return items unless params[:t]

      items << params[:t]
      items
    end

    def linkpath(ary, prefix='/list')
      [prefix, ary.map{|v| urlencode(v)}].join('/')
    end

    def format_number(num)
      # 12345678 => "12,345,678"
      num.to_s.reverse.chars.each_slice(3).map{|slice| slice.reverse.join}.reverse.join(',')
    end

    def selected?(real, option)
      real == option ? 'selected' : ''
    end
  end

  module Stash
    def stash
      @stash ||= {}
    end
  end

  before { request.extend Stash }

  set(:graph) do |type|
    condition do
      graph = case type
              when :simple
                if params[:graph_id]
                  data().get_by_id(params[:graph_id].to_i)
                else
                  data().get(params[:service_name], params[:section_name], params[:graph_name])
                end
              when :complex
                if params[:complex_id]
                  data().get_complex_by_id(params[:complex_id].to_i)
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
    erb :docs, layout: :base, locals: { pathinfo: [nil, nil, nil, nil, :docs] }
  end

  get '/' do
    services = []
    data().get_services.each do |service|
      services << {:name => service, :sections => data().get_sections(service)}
    end
    erb :index, layout: :base, locals: { pathinfo: pathinfo(params), services: services }
  end

  get '/list/:service_name' do
    services = []
    sections = data().get_sections(params[:service_name])
    services << { name: params[:service_name], sections: sections }
    erb :index, layout: :base, :locals => { pathinfo: pathinfo(params), services: services }
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
    pi = pathinfo(req_params.hash)
    erb :list, layout: :base, locals: { pathinfo: pi, params: req_params.hash, graphs: graphs }
  end

  get '/view_graph/:service_name/:section_name/:graph_name', :graph => :simple do
    req_params = validate(params, graph_view_spec)
    pi = pathinfo(req_params.hash)
    erb :view_graph, layout: :base, locals: { pathinfo: pi, params: req_params.hash, graphs: [ request.stash[:graph] ], view_complex: false }
  end

  get '/view_complex/:service_name/:section_name/:graph_name', :graph => :complex do
    req_params = validate(params, graph_view_spec)
    pi = pathinfo(req_params.hash)
    erb :view_graph, layout: :base, locals: { pathinfo: pi, params: req_params.hash, graphs: [ request.stash[:graph] ], view_complex: true }
  end

  get '/edit/:service_name/:section_name/:graph_name', :graph => :simple do
      erb :edit, layout: :base, locals: { pathinfo: [nil,nil,nil,nil,:edit], graph: request.stash[:graph] }
  end

  post '/edit/:service_name/:section_name/:graph_name', :graph => :simple do
    edit_graph_spec = {
      service_name: { rule: rule(:not_blank) },
      section_name: { rule: rule(:not_blank) },
      graph_name:  { rule: rule(:not_blank) },
      description: { default: '' },
      sort:  { rule: [ rule(:not_blank), rule(:int_range, 0..19) ] },
      adjust:    { default: '*', rule: [ rule(:not_blank), rule(:choice, '*', '/') ] },
      adjustval: { default: '1', rule: [ rule(:not_blank), rule(:natural) ] },
      unit: { default: '' },
      color: { rule: [ rule(:not_blank), rule(:regexp, /^#[0-9a-f]{6}$/i) ] },
      type:  { rule: [ rule(:not_blank), rule(:choice, 'AREA', 'LINE1', 'LINE2') ] },
      llimit:  { rule: [ rule(:not_blank), number_type_rule() ] },
      ulimit:  { rule: [ rule(:not_blank), number_type_rule() ] },
    }
    req_params = validate(params, edit_graph_spec)

    if req_params.has_error?
      json({error: 1, messages: req_params.errors})
    else
      data().update_graph(request.stash[:graph].id, req_params.hash)
      edit_path = "/view_graph/%s/%s/%s" % [:service_name,:section_name,:graph_name].map{|s| urlencode(req_params[s])}
      json({error: 0, location: url_for(edit_path)})
    end
  end

  post '/delete/:service_name/:section_name' do
    graphs = data().get_graphs(params[:service_name], params[:section_name])
    graphs.each do |graph|
      if graph.complex?
        data().remove_complex(graph.id)
      else
        data().remove(graph.id)
        rrd().remove(graph)
      end
    end
    service_path = "/list/%s" % [ urlencode(params[:service_name]) ]
    json({ error: 0, location: url_for(service_path) })
  end

  post '/delete/:service_name/:section_name/:graph_name', :graph => :simple do
    delete(request.stash[:graph]).to_json
  end

  get '/add_complex' do
    graphs = data().get_all_graph_name
    erb :add_complex, layout: :base, locals: { pathinfo: [nil, nil, nil, nil, :add_complex], params: params, graphs: graphs }
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
      'type-2'.to_sym => {
        array: true, size: (type2s_num..type2s_num),
        rule: [ rule(:not_blank), rule(:choice, 'AREA', 'LINE1', 'LINE2') ],
      },
      'path-2'.to_sym => {
        array: true, size: (type2s_num..type2s_num),
        rule: [ rule(:not_blank), rule(:natural) ],
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
        rule: rule(:lambda, ->(service,section,graph){ data().get_complex(service,section,graph).nil? }, "duplicate graph path")
      },
    }
    specs.update(additional)
    req_params = validate(params, specs)

    if req_params.has_error?
      json({error: 1, messages: req_params.errors})
    else
      data().create_complex(req_params[:service_name], req_params[:section_name], req_params[:graph_name], req_params.hash)
      created_path = "/list/%s/%s" % [:service_name,:section_name].map{|s| urlencode(req_params[s])}
      json({error: 0, location: url_for(created_path)})
    end
  end

  get '/edit_complex/:complex_id', :graph => :complex do
    graphs = data().get_all_graph_name
    graph_dic = Hash[ graphs.map{|g| [g[:id], g]} ]
    erb :edit_complex, layout: :base, locals: { pathinfo: [nil, nil, nil, nil, :edit_complex], complex: request.stash[:graph], graphs: graphs, dic: graph_dic }
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
            graph.nil? || graph.id == current_graph_id
          }, "graph path must be unique")
      },
    }
    specs.update(additional)
    req_params = validate(params, specs)

    if req_params.has_error?
      json({error: 1, messages: req_params.errors})
    else
      data().update_complex(request.stash[:graph].id, req_params.hash)
      created_path = "/list/%s/%s" % [:service_name,:section_name].map{|s| urlencode(req_params[s])}
      json({error: 0, location: url_for(created_path)})
    end
  end

  post '/delete_complex/:complex_id', :graph => :complex do
    delete(request.stash[:graph]).to_json
  end

  graph_rendering_request_spec = {
    service_name: not_specified_or_not_whitespece,
    section_name: not_specified_or_not_whitespece,
    graph_name: not_specified_or_not_whitespece,
    complex: not_specified_or_not_whitespece,
    t: { default: 'd', rule: rule(:choice, 'd', 'h', 'm', 'sh', 'sd') },
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
    legend: { default: 'true', rule: rule(:bool) },
    notitle: { default: 'false', rule: rule(:bool) },
    xgrid: { default: '' },
    ygrid: { default: '' },
    upper_limit: { default: '' },
    lower_limit: { default: '' },
    rigid: { default: 'false', rule: rule(:bool) },
    sumup: { default: 'false', rule: rule(:bool) },
    step: { excludable: true, rule: rule(:uint) },
    cf: { default: 'AVERAGE', rule: rule(:choice, 'AVERAGE', 'MAX') }
  }

  get '/complex/graph/:service_name/:section_name/:graph_name', :graph => :complex do
    req_params = validate(params, graph_rendering_request_spec)

    data = []
    request.stash[:graph].data_rows.each do |row|
      g = data().get_by_id(row[:graph_id])
      g.c_type = row[:type]
      g.stack = row[:stack]
      data << g
    end

    graph_img = rrd().graph(data, req_params.hash)
    [200, {'Content-Type' => 'image/png'}, graph_img]
  end

  get '/complex/xport/:service_name/:section_name/:graph_name', :graph => :complex do
    req_params = validate(params, graph_rendering_request_spec)

    data = []
    request.stash[:graph].data_rows.each do |row|
      g = data().get_by_id(row[:graph_id])
      g.c_type = row[:type]
      g.stack = row[:stack]
      data << g
    end

    json(rrd().export(data, req_params.hash))
  end

  get '/graph/:service_name/:section_name/:graph_name', :graph => :simple do
    req_params = validate(params, graph_rendering_request_spec)
    graph_img = rrd().graph(request.stash[:graph], req_params.hash)
    [200, {'Content-Type' => 'image/png'}, graph_img]
  end

  get '/xport/:service_name/:section_name/:graph_name', :graph => :simple do
    req_params = validate(params, graph_rendering_request_spec)
    json(rrd().export(request.stash[:graph], req_params.hash))
  end

  get '/graph/:complex' do
    req_params = validate(params, graph_rendering_request_spec)

    data = []
    req_params[:complex].split(':').each_slice(4).each do |type, id, stack|
      g = data().get_by_id(id)
      next unless g
      g.c_type = type
      g.stack = !!(stack =~ /^(1|true)$/i)
      data << g
    end
    graph_img = rrd().graph(data, req_params.hash)
    [200, {'Content-Type' => 'image/png'}, graph_img]
  end

  get '/xport/:complex' do
    req_params = validate(params, graph_rendering_request_spec)

    data = []
    req_params[:complex].split(':').each_slice(4).each do |type, id, stack|
      g = data().get_by_id(id)
      next unless g
      g.c_type = type
      g.stack = !!(stack =~ /^(1|true)$/i)
      data << g
    end

    json(rrd().export(data, req_params.hash))
  end

  get '/api/:service_name/:section_name/:graph_name', :graph => :simple do
    json(request.stash[:graph].to_hash)
  end

  post '/api/:service_name/:section_name/:graph_name' do
    api_graph_post_spec = {
      service_name: { rule: rule(:not_blank) },
      section_name: { rule: rule(:not_blank) },
      graph_name: { rule: rule(:not_blank) },
      number: { rule: [ rule(:not_blank), number_type_rule() ] },
      mode: { default: 'gauge', rule: rule(:choice, 'count', 'gauge', 'modified', 'derive') },
      color: { default: '', rule: rule(:regexp, /^(|#[0-9a-f]{6})$/i) },
      description: { default: '' },
    }
    req_params = validate(params, api_graph_post_spec)

    if req_params.has_error?
      halt json({ error: 1, messages: req_params.errors })
    end

    graph = nil
    graph = data().update(
      req_params[:service_name], req_params[:section_name], req_params[:graph_name],
      req_params[:number], req_params[:mode], req_params[:color]
    )
    unless req_params[:description].empty?
      data().update_graph_description(graph.id, req_params[:description])
    end
    json({ error: 0, data: graph.to_hash })
  end

  # graph4json => Focuslight::Graph#to_hash
  # graph4internal => Focuslight::Graph.hash2request(hash)

  # alias to /api/:service_name/:section_name/:graph_name
  get '/json/graph/:service_name/:section_name/:graph_name', :graph => :simple do
    json(request.stash[:graph].to_hash)
  end

  get '/json/complex/:service_name/:section_name/:graph_name', :graph => :complex do
    json(request.stash[:graph].to_hash)
  end

  # alias to /delete/:service_name/:section_name/:graph_name
  post '/json/delete/graph/:service_name/:section_name/:graph_name', :graph => :simple do
    delete(request.stash[:graph]).to_json
  end

  post '/json/delete/graph/:graph_id', :graph => :simple do
    delete(request.stash[:graph]).to_json
  end

  post '/json/delete/complex/:service_name/:section_name/:graph_name', :graph => :complex do
    delete(request.stash[:graph]).to_json
  end

  post '/json/delete/complex/:complex_id', :graph => :complex do
    delete(request.stash[:graph]).to_json
  end

  get '/json/graph/:graph_id', :graph => :simple do
    json(request.stash[:graph].to_hash)
  end

  get '/json/complex/:complex_id', :graph => :complex do
    json(request.stash[:graph].to_hash)
  end

  get '/json/list/graph' do
    json(data().get_all_graph_name()) #TODO return type?
  end

  get '/json/list/complex' do
    json(data().get_all_complex_graph_name()) #TODO return type?
  end

  get '/json/list/all' do
    json( (data().get_all_graph_all() + data().get_all_complex_graph_all()).map(&:to_hash) )
  end

  # TODO in create/edit, validations about json object properties, sub graph id existense, ....
  post '/json/create/complex' do
    spec = JSON.parse(request.body.read || '{}', symbolize_names: true)

    exists_simple = data().get(spec[:service_name], spec[:section_name], spec[:graph_name])
    exists_complex = data().get_complex(spec[:service_name], spec[:section_name], spec[:graph_name])
    if exists_simple || exists_complex
      halt 409, "Invalid target: graph path already exists: #{spec[:service_name]}/#{spec[:section_name]}/#{spec[:graph_name]}"
    end

    if spec[:data].nil? || spec[:data].size < 2
      halt 400, "Invalid argument: data (sub graph list (size >= 2)) required"
    end

    spec[:complex] = true
    spec[:description] ||= ''
    spec[:sumup] ||= false
    spec[:sort] ||= 19

    spec[:data].each do |data|
      data[:type] ||= 'AREA'
      data[:stack] = true unless data.has_key?(:stack)
    end

    internal = Focuslight::Graph.hash2request(spec)
    data().create_complex(spec[:service_name], spec[:section_name], spec[:graph_name], internal)
    section_path = "/list/%s/%s" % [:service_name,:section_name].map{|s| urlencode(spec[s])}
    json({ error: 0, location: url_for(section_path) })
  end

  # post '/json/edit/{type:(?:graph|complex)}/:id' => sub {
  post '/json/edit/:type/:id' do
    graph = case params[:type]
            when 'graph'
              data().get_by_id( params[:id] )
            when 'complex'
              data().get_complex_by_id( params[:id] )
            else
              nil
            end
    unless graph
      halt 404
    end

    spec = JSON.parse(request.body.read || '{}', symbolize_names: true)
    id = spec.delete(:id) || graph.id

    if spec.has_key?(:data)
      spec[:data].each do |data|
        data[:type] ||= 'AREA'
        data[:stack] = true unless data.has_key?(:stack)
      end
    end

    internal = Focuslight::Graph.hash2request(spec)
    if graph.complex?
      data().update_complex(graph.id, internal)
    else
      data().update_graph(graph.id, internal)
    end
    json({ error: 0 })
  end
end
