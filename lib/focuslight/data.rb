require "focuslight"
require "focuslight/config"
require "focuslight/graph"

class Focuslight::Data
  SQLITE_FILENAME = "gforecast.db" # comapibility with GrowthForecast

  def initialize
    @datadir = Focuslight::Config.get(:datadir)
    @floatings = Focuslight::Config.get(:float_support)
    filepath = File.join(@datadir, SQLITE_FILENAME)

    @db = SQLite3::Database.new(filepath)
    @db.results_as_hash = true

    @db.execute 'PRAGMA journal_mode = WAL'
    @db.execute 'PRAGMA synchronous = NORMAL'
  end

  def execute(*args)
    @db.execute(*args)
  end

  def transaction
    @db.transaction(:immediate) do |db|
      yield db
    end
  end

  def number_type
    @floatings ? 'REAL' : 'INT'
  end

  def get(service, section, graph)
    data = @db.get_first_row(
      'SELECT * FROM graphs WHERE service_name = ? AND section_name = ? AND graph_name = ?',
      [service, section, graph]
    )
    data && Focuslight::Graph.concrete(data)
  end

  def get_by_id(id)
    rows = @db.get_first_row(
      'SELECT * FROM graphs WHERE id = ?',
      [id]
    )
    data && Focuslight::Graph.concrete(data)
  end

  def get_by_id_for_rrdupdate(id, target=:long) # get_by_id_for_rrdupdate_short == get_by_id_for_rrdupdate(id, :short)
    tablename = (target == :short ? 'prev_short_graphs' : 'prev_graphs')

    data = @db.get_first_row(
      'SELECT * FROM graphs WHERE id = ?',
      [id]
    )
    return nil unless data
    graph = Focuslight::Graph.concrete(data)

    subtract = nil

    @db.transaction(:immediate) do |db|
      prev = db.get_first_row(
        "SELECT * FROM #{tablename} WHERE graph_id = ?", # TODO: if mysql, ' FOR UPDATE'
        [id]
      )

      if !prev
        subtract = 'U'
        db.execute(
          'INSERT INTO #{tablename} (graph_id, number, subtract, updated_at) VALUES (?,?,?,?)',
          [id, graph.number, nil, graph.updated_at_time.to_i]
        )
      elsif graph.updated_at_time.to_i != prev['updated_at']
        subtract = graph.number - prev['number'].to_i
        db.execute(
          'UPDATE #{tablename} SET number=?, subtract=?, updated_at=? WHERE graph_id = ?',
          [graph.number, subtract, graph.updated_at_time.to_i, graph.id]
        )
      else
        if data.mode == 'gauge' || data.mode == 'modified'
          subtract = prev['subtract']
          subtract = 'U' unless subtract
        else
          subtract = 0
        end
      end
    end # commit

    if target == :short
      graph.subtract_short = subtract
    else
      graph.subtract = subtract
    end
    graph
  end

  def update(service, section, graph, number, mode, color)
    @db.transaction do |db|
      data = db.get_first_row(
        'SELECT * FROM graphs WHERE service_name = ? AND section_name = ? AND graph_name = ?', # TODO: if mysql, ' FOR UPDATE'
        [service, section, graph]
      )
      if data
        graph = Focuslight::Graph.concrete(data)
        if mode == 'count'
          number += graph.number
        end
        if mode != 'modified' || (mode == 'modified' && graph.number != number)
          color ||= graph.color
          db.execute(
            'UPDATE graphs SET number=?, mode=?, color=?, updated_at=? WHERE id = ?',
            [number, mode, color, Time.now.to_i, graph.id]
          )
        end
      else
        color ||= '#' + ['33', '66', '99', 'cc'].shuffle.slice(0,3).join
        # COLUMNS = %w(service_name section_name graph_name number mode color llimit sllimit created_at updated_at)
        columns = Focuslight::SimpleGraph::COLUMNS.join(',')
        # PLACEHOLDERS = COLUMNS.map{|c| '?'}
        placeholders = Focuslight::SimpleGraph::PLACEHOLDERS.join(',')
        current_time = Time.now.to_i
        db.execute(
          "INSERT INTO graphs (#{columns}) VALUES (#{placeholders})",
          [service, section, graph, number, mode, color, -1000000000, -100000 , current_time, current_time]
        )
      end

      data = db.get_first_row(
        'SELECT * FROM graphs WHERE service_name = ? AND section_name = ? AND graph_name = ?',
        [service, section, graph]
      )
    end # transaction

    Focuslight::Graph.concrete(data)
  end

  def update_graph(id, args)
    graph = get_by_id(id)
    return nil unless graph

    graph.update(args)
    sql = <<SQL
UPDATE graphs
  SET service_name=?, section_name=?, graph_name=?,
      description=?, sort=?, gmode=?, color=?, type=?, stype=?,
      llimit=?, ulimit=?, sllimit=?, sulimit=?, meta=?
  WHERE id = ?
SQL
    @db.execute(sql,
      [
        graph.service, graph.section, graph.graph,
        graph.description, graph.sort, graph.gmode, graph.color, graph.type, graph.stype,
        graph.llimit, graph.ulimit, graph.sllimit, graph.sulimit, graph.meta,
        graph.id
      ]
    )
    true
  end

  def update_graph_description(id, description)
    @db.execute(
      'UPDATE graphs SET description=? WHERE id = ?',
      [description, id]
    )
    true
  end

  def get_services
    rows1 = @db.execute('SELECT DISTINCT service_name FROM graphs ORDER BY service_name')
    rows2 = @db.execute('SELECT DISTINCT service_name FROM complex_graphs ORDER BY service_name')
    (rows1 + rows2).map{|row| row['service_name']}.uniq.sort
  end

  def get_sections(service)
    rows1 = @db.execute(
      'SELECT DISTINCT section_name FROM graphs WHERE service_name = ? ORDER BY section_name',
      [service]
    )
    rows2 = @db.execute(
      'SELECT DISTINCT section_name FROM complex_graphs WHERE service_name = ? ORDER BY section_name',
      [service]
    )
    (rows1 + rows2).map{|row| row['section_name']}.uniq.sort
  end

  def get_graphs(service, section)
    rows1 = @db.execute(
      'SELECT * FROM graphs WHERE service_name = ? AND section_name = ? ORDER BY sort DESC',
      [service, section]
    )
    rows2 = @db.execute(
      'SELECT * FROM complex_graphs WHERE service_name = ? AND section_name = ? ORDER BY sort DESC',
      [service, section]
    )
    (rows1 + rows2).map{|row| Focuslight::Graph.concrete(row)}.sort{|a,b| b.sort <=> a.sort}
  end

  def get_all_graph_id
    @db.execute('SELECT id FROM graphs')
  end

  def get_all_graph_name
    sql = <<SQL
SELECT id,service_name,section_name,graph_name
  FROM graphs
  ORDER BY service_name, section_name, graph_name DESC
SQL
    @db.execute(sql)
  end

  def get_all_graph_all
    rows = @db.execute('SELECT * FROM graphs ORDER BY service_name, section_name, graph_name DESC')
    return [] unless rows
    rows.map{|row| Focuslight::Graph.concrete(row)}
  end

  def remove(id)
    @db.transaction do |db|
      db.execute('DELETE FROM graphs WHERE id = ?', id)
      db.execute('DELETE FROM prev_graphs WHERE graph_id = ?', id)
    end
  end

  def get_complex(service, section, graph)
    data = @db.get_first_row(
      'SELECT * FROM complex_graphs WHERE service_name = ? AND section_name = ? AND graph_name = ?',
      [service, section, graph]
    )
    data && Focuslight::Graph.concrete(data)
  end

  def get_complex_by_id(id)
    data = @db.get_first_row(
      'SELECT * FROM complex_graphs WHERE id = ?',
      [id]
    )
    data && Focuslight::Graph.concrete(data)
  end

  def create_complex(service, section, graph, args)
    meta = JSON.stringify(Focuslight::ComplexGraph.meta_clean(args))
    now = Time.now.to_i
    sql = <<SQL
INSERT INTO complex_graphs (service_name, section_name, graph_name, description, sort, meta,  created_at, updated_at)
       VALUES (?,?,?,?,?,?,?,?)
SQL
    @db.execute(sql, [service, section, graph, args['description'], args['sort'].to_i, meta, now, now])

    get_complex(service, section, graph)
  end

  def update_complex(id, args)
    graph = get_complex_by_id(id)
    return nil unless graph

    graph.update(args)
    sql = <<SQL
UPDATE complex_graphs
  SET service_name = ?, section_name = ?, graph_name = ?,
      description = ?, sort = ?, meta = ?, updated_at = ?
  WHERE id=?'
SQL
    @db.execute(sql,
      [
        graph.service, graph.section, graph.graph,
        graph.description, graph.sort, graph.meta, Time.now.to_i,
        graph.id
      ]
    )

    get_complex_by_id(id)
  end

  def remove_complex(id)
    @db.execute('DELETE FROM complex_graphs WHERE id = ?', [id])
  end

  def get_all_complex_graph_id
    @db.execute('SELECT id FROM complex_graphs')
  end

  def get_all_complex_graph_name
    sql = <<SQL
SELECT id,service_name,section_name,graph_name
  FROM complex_graphs
  ORDER BY service_name, section_name, graph_name DESC
SQL
    @db.execute(sql)
  end

  def get_all_complex_graph_all
    rows = @db.execute('SELECT * FROM complex_graphs ORDER BY service_name, section_name, graph_name DESC')
    return [] unless rows
    rows.map{|row| Focuslight::Graph.concrete(row)}
  end
end
