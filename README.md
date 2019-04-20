# Focuslight

[![Build Status](https://travis-ci.org/focuslight/focuslight.png?branch=master)](https://travis-ci.org/focuslight/focuslight)

Focuslight is a lightning Fast Graphing/Visualization tool, built on RRDTool. It is a Ruby clone of [GrowthForecast](http://kazeburo.github.io/GrowthForecast/).

Focuslight is compatible with:
 * stored data files
   * database (sqlite) and graphs (rrdtool)
 * almost all HTTP API requests, except for:
   * `export` support
 * almost all of features, except for:
   * `subtract` support (`gmode`, `stype`, `sllimit`, `sulimit` parameters)

## Prerequisites

RRDTool and its dependencies must be installed before installing Focuslight.

* RHEL/CentOS 6.x
  * Add `epel` repository, then `sudo yum install rrdtool rrdtool-devel`
* Ubuntu
  * `sudo apt-get install rrdtool librrd-dev`
* OSX
  * `brew install rrdtool`

## Installation

Install focuslight with Ruby 2.1 or later. 

### Gem package

Five easy steps on installation with gem and SQLite.

```bash
$ gem install focuslight
$ focuslight new
$ cd focuslight
$ focuslight init # creates database scheme on SQLite
$ focuslight start
```

Then see `http://localhost:5125/`. Refer `Using MySQL` section to use MySQL instead of SQLite. 

### Git repository

Install from git repository. 

```bash
$ git clone https://github.com/focuslight/focuslight.git
$ cd focuslight
$ bundle
$ bundle exec focuslight init # creates database scheme on SQLite
$ bundle exec focuslight start
```

Then see `http://localhost:5125/`. Refer `Using MySQL` section to use MySQL instead of SQLite. 

### Using MySQL

Change `DBURL` parameter on .env file to `mysql2` version like `DBURL=mysql2://root:@localhost/focuslight`. 
Also configure the database name, the user name, and the password. See the Configuration section. 

Then, create the database and assign permissions to the user as

```
mysql> CREATE DATABASE focuslight;
mysql> GRANT  CREATE, ALTER, DELETE, INSERT, UPDATE, SELECT \\
  ON focuslight.* TO 'user'\@'localhost' IDENTIFIED BY password;
```

After that, follow the same procedure with the SQLite case.

## Configuration

To configure Focuslight, edit the `.env` file in the project root directory.

The default configuration is as follows:

```
DATADIR=./data
PORT=5125
HOST=0.0.0.0
# FRONT_PROXY
# ALLOW_FROM
# 1MIN_METRICS=n
FLOAT_SUPPORT=n # y
DBURL=sqlite://data/gforecast.db
DBTIMEOUT=60000
# DBURL=mysql2://root:@localhost/focuslight
# RRDCACHED=n
# MOUNT=/
LOG_PATH=log/application.log
LOG_LEVEL=warn
```

## Switch from GrowthForecast

1. Copy GrowthForecast's `datadir` directory (and its contents) to `./data` (or where you specified)
1. Execute Focuslight

## TODO

* Merge GrowthForecast's commits after Jan 09, 2014
  * api endpoint link label
* RRDCached support
* Front proxies and source address restrictions
* HTTP API mount point support
* Daemonize support
* Add tests, and tests, and more tests

## Incompatible Features

Focuslight has following incompatibilities with GrowthForecast as specifications.

### Subtract

[GrowthForecast](http://kazeburo.github.io/GrowthForecast/index.html) has subtract graph support (gmode=subtract),
but focuslight does not have it because subtract graphs can be created using mode=derive like:

```
curl -d "number=10&mode=derive" http://localhost:5125/api/service/section/graph
```

As a demo, you may run following shell codes.
The number is incremental, but derive graph shows you the difference as a graph, which results in 1 in this demo.

```
number=1
while true; do
  curl -d "number=${number}&mode=derive" http://localhost:5125/api/service/section/graph
  number=$((number+1))
  sleep 60
done
```

In addition, because focuslight does not support subtract graphs, `gmode`, `stype`, `sllimit`, and `sulimit`
parameters on HTTP APIs are not available. In the case of POST (create, edit), they are ignored.
In the case of GET, they are not returned.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The MIT License (MIT)

Copyright (c) 2014- tagomoris

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
