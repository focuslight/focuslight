require "focuslight"
require "focuslight/config"
require "focuslight/logger"
require "focuslight/graph"
require "sequel"

class Focuslight::Data
  include Focuslight::Logger

  def initialize
    @db = Sequel.connect(Focuslight::Config.get(:dburl), logger: Focuslight.logger, timeout: Focuslight::Config.get(:dbtimeout).to_i)
    @datadir = Focuslight::Config.get(:datadir)
    @floatings = Focuslight::Config.get(:float_support) == "y"

    if @db.database_type == :sqlite
      @db.run 'PRAGMA journal_mode = WAL'
      @db.run 'PRAGMA synchronous = NORMAL'
    end
    @graphs = @db.from(:graphs)
    @complex_graphs = @db.from(:complex_graphs)
  end

  def number_type
    @floatings ? Float : Integer
  end

  def create_tables
    ntype = number_type

    @db.transaction do
      @db.create_table :graphs do
        primary_key :id, Integer # Notice that SQLite actually creates integer primary key
        column :service_name, String, null: false
        column :section_name, String, null: false
        column :graph_name, String, null: false
        column :number, ntype, default: 0
        column :mode, String, default: "gauge", null: false
        column :description, String, default: "", null: false
        column :sort, Integer, default: 0, null: false
        column :color, String, default: "#00CC00", null: false
        column :ulimit, ntype, default: 1000000000000000, null: false
        column :llimit, ntype, default: 0, null: false
        column :type, String, default: "AREA", null: false
        String :meta, text: true
        column :created_at, Integer, null: false
        column :updated_at, Integer, null: false
        unique [:service_name, :section_name, :graph_name]
      end

      @db.create_table :complex_graphs do
        primary_key :id, Integer # Notice that SQLite actually creates integer primary key
        column :service_name, String, null: false
        column :section_name, String, null: false
        column :graph_name, String, null: false
        column :number, ntype, default: 0
        column :description, String, default: "", null: false
        column :sort, Integer, default: 0, null: false
        String :meta, text: true
        column :created_at, Integer, null: false
        column :updated_at, Integer, null: false
        unique [:service_name, :section_name, :graph_name]
      end
    end
  end

  def execute(*args)
    @db.run(*args)
  end

  def transaction
    @db.transaction do
      yield @db
    end
  end

  def get(service, section, graph)
    data = @graphs.where(service_name: service, section_name: section, graph_name: graph).first
    data && Focuslight::Graph.concrete(data)
  end

  def get_by_id(id)
    data = @graphs[id: id]
    data && Focuslight::Graph.concrete(data)
  end

  def get_by_id_for_rrdupdate(id, target=:normal) # get_by_id_for_rrdupdate_short == get_by_id_for_rrdupdate(id, :short)
    data = @graphs[id: id]
    return nil unless data
    graph = Focuslight::Graph.concrete(data)
  end

  def update(service_name, section_name, graph_name, number, mode, color)
    data = nil
    @db.transaction do
      data = @graphs.where(service_name: service_name, section_name: section_name, graph_name: graph_name).first
      if data
        graph = Focuslight::Graph.concrete(data)
        if mode == 'count'
          number += graph.number
        end
        if mode != 'modified' || (mode == 'modified' && graph.number != number)
          color = graph.color if color.empty?
          @graphs.where(id: graph.id).update(number: number, mode: mode, color: color, updated_at: Time.now.to_i)
        end
      else
        color = '#' + ['33', '66', '99', 'cc'].shuffle.slice(0,3).join if color.empty?
        # COLUMNS = %w(service_name section_name graph_name number mode color llimit created_at updated_at)
        columns = Focuslight::SimpleGraph::COLUMNS.join(',')
        # PLACEHOLDERS = COLUMNS.map{|c| '?'}
        placeholders = Focuslight::SimpleGraph::PLACEHOLDERS.join(',')
        current_time = Time.now.to_i
        @graphs.insert(
                       service_name: service_name,
                       section_name: section_name,
                       graph_name: graph_name,
                       number: number,
                       mode: mode,
                       color: color,
                       llimit: -1000000000,
                       created_at: current_time,
                       updated_at: current_time)
      end

      data = @graphs.where(service_name: service_name, section_name: section_name, graph_name: graph_name).first
    end # transaction

    Focuslight::Graph.concrete(data)
  end

  def update_graph(id, args)
    graph = get_by_id(id)
    return nil unless graph

    graph.update(args)
    @graphs.where(id: graph.id)
      .update(
              service_name: graph.service,
              section_name: graph.section,
              graph_name: graph.graph,
              description: graph.description,
              sort: graph.sort,
              color: graph.color,
              type: graph.type,
              llimit: graph.llimit,
              ulimit: graph.ulimit,
              meta: graph.meta
              )
    true
  end

  def update_graph_description(id, description)
    @graphs.where(id: id).update(description: description)
    true
  end

  def get_services
    rows1 = @graphs.order(:service_name).all
    rows2 = @complex_graphs.order(:service_name).all
    (rows1 + rows2).map{|row| row[:service_name]}.uniq.sort
  end

  def get_sections(service)
    rows1 = @graphs.select(:section_name).order(:section_name).where(service_name: service).all
    rows2 = @complex_graphs.select(:section_name).order(:section_name).where(service_name: service).all
    (rows1 + rows2).map{|row| row[:section_name]}.uniq.sort
  end

  def get_graphs(service, section)
    rows1 = @graphs.order(Sequel.desc(:sort)).where(service_name: service, section_name: section).all
    rows2 = @complex_graphs.order(Sequel.desc(:sort)).where(service_name: service, section_name: section).all
    (rows1 + rows2).map{|row| Focuslight::Graph.concrete(row)}.sort{|a,b| b.sort <=> a.sort}
  end

  def get_all_graph_id
    @graphs.select(:id).all
  end

  def get_all_graph_name
    @graphs.select(:id, :service_name, :section_name, :graph_name).reverse_order(:service_name, :section_name, :graph_name).all
  end

  def get_all_graph_all
    rows = @graphs.reverse_order(:service_name, :section_name, :graph_name).all
    rows.map{|row| Focuslight::Graph.concrete(row)}
  end

  def remove(id)
    @db.transaction do
      @graphs.where(id: id).delete
    end
  end

  def get_complex(service, section, graph)
    data = @complex_graphs.where(service_name: service, section_name: section, graph_name: graph).first
    data && Focuslight::Graph.concrete(data)
  end

  def get_complex_by_id(id)
    data = @complex_graphs.where(id: id).first
    data && Focuslight::Graph.concrete(data)
  end

  def create_complex(service, section, graph, args)
    description = args[:description]
    sort = args[:sort]
    meta = Focuslight::ComplexGraph.meta_clean(args).to_json
    now = Time.now.to_i
    @complex_graphs.insert(
                           service_name: service,
                           section_name: section,
                           graph_name: graph,
                           description: description,
                           sort: sort.to_i,
                           meta: meta,
                           created_at: now,
                           updated_at: now,
                           )
    get_complex(service, section, graph)
  end

  def update_complex(id, args)
    graph = get_complex_by_id(id)
    return nil unless graph

    graph.update(args)
    @complex_graphs.where(id: graph.id)
      .update(
              service_name: graph.service,
              section_name: graph.section,
              graph_name: graph.graph,
              description: graph.description,
              sort: graph.sort,
              meta: graph.meta,
              updated_at: Time.now.to_i,
              )

    get_complex_by_id(id)
  end

  def remove_complex(id)
    @complex_graphs.where(id: id).delete
  end

  def get_all_complex_graph_id
    @complex_graphs.select(:id).all
  end

  def get_all_complex_graph_name
    @complex_graphs.select(:id, :service_name, :section_name, :graph_name).reverse_order(:service_name, :section_name, :graph_name).all
  end

  def get_all_complex_graph_all
    rows = @complex_graphs.reverse_order(:service_name, :section_name, :graph_name)
    return [] unless rows
    rows.map{|row| Focuslight::Graph.concrete(row)}
  end
end
