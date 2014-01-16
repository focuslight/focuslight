require "focuslight"
require "focuslight/config"
require "focuslight/data"
require "sqlite3"

module Focuslight::Init
  def self.run
    data = Focuslight::Data.new
    number_type = data.number_type

    graphs_create = <<"SQL"
CREATE TABLE IF NOT EXISTS graphs (
    id           INTEGER NOT NULL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    section_name VARCHAR(255) NOT NULL,
    graph_name   VARCHAR(255) NOT NULL,
    number       #{number_type} NOT NULL DEFAULT 0,
    mode         VARCHAR(255) NOT NULL DEFAULT 'gauge',
    description  VARCHAR(255) NOT NULL DEFAULT '',
    sort         UNSIGNED INT NOT NULL DEFAULT 0,
    gmode        VARCHAR(255) NOT NULL DEFAULT 'gauge',
    color        VARCHAR(255) NOT NULL DEFAULT '#00CC00',
    ulimit       #{number_type} NOT NULL DEFAULT 1000000000000000,
    llimit       #{number_type} NOT NULL DEFAULT 0,
    sulimit      #{number_type} NOT NULL DEFAULT 100000,
    sllimit      #{number_type} NOT NULL DEFAULT 0,
    type         VARCHAR(255) NOT NULL DEFAULT 'AREA',
    stype         VARCHAR(255) NOT NULL DEFAULT 'AREA',
    meta         TEXT,
    created_at   UNSIGNED INT NOT NULL,
    updated_at   UNSIGNED INT NOT NULL,
    UNIQUE  (service_name, section_name, graph_name)
)
SQL

    prev_graphs_create = <<"SQL"
CREATE TABLE IF NOT EXISTS prev_graphs (
    graph_id     INT NOT NULL,
    number       #{number_type} NOT NULL DEFAULT 0,
    subtract     #{number_type},
    updated_at   UNSIGNED INT NOT NULL,
    PRIMARY KEY  (graph_id)
)
SQL

    prev_short_graphs_create = <<"SQL"
CREATE TABLE IF NOT EXISTS prev_short_graphs (
    graph_id     INT NOT NULL,
    number       #{number_type} NOT NULL DEFAULT 0,
    subtract     #{number_type},
    updated_at   UNSIGNED INT NOT NULL,
    PRIMARY KEY  (graph_id)
)
SQL

    complex_graphs_create = <<"SQL"
CREATE TABLE IF NOT EXISTS complex_graphs (
    id           INTEGER NOT NULL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    section_name VARCHAR(255) NOT NULL,
    graph_name   VARCHAR(255) NOT NULL,
    number       #{number_type} NOT NULL DEFAULT 0,
    description  VARCHAR(255) NOT NULL DEFAULT '',
    sort         UNSIGNED INT NOT NULL DEFAULT 0,
    meta         TEXT,
    created_at   UNSIGNED INT NOT NULL,
    updated_at   UNSIGNED INT NOT NULL,
    UNIQUE  (service_name, section_name, graph_name)
)
SQL

    data.transaction do |conn|
      conn.execute(graphs_create)
      conn.execute(prev_graphs_create)
      conn.execute(prev_short_graphs_create)
      conn.execute(complex_graphs_create)
    end
  end
end
