# Focuslight

[![Build Status](https://secure.travis-ci.org/focuslight/focuslight.png?branch=master)](http://travis-ci.org/focuslight/focuslight)

Focuslight is a lightning Fast Graphing/Visualization tool, built on RRDTool. It is a Ruby clone of [GrowthForecast](http://kazeburo.github.io/GrowthForecast/).

Focuslight is compatible with:
 * stored data files
   * database (sqlite) and graphs (rrdtool)
 * almost all HTTP API requests, except for:
   * `export` support
 * almost all of features, except for:
   * `subtract` support (`gmode`, `stype`, `sllimit`, `sulimit` parameters)

Focuslight is currently lacking some GrowthForecast features:
 * MySQL support

## Prerequisites

RRDTool and its dependencies must be installed before installing Focuslight.

* RHEL/CentOS 6.x
  * Add `epel` repository, then `sudo yum install rrdtool rrdtool-devel`
* Ubuntu
  * `sudo apt-get rrdtool`
* OSX
  * `brew install rrdtool`

## Installation

Install focuslight with Ruby 2.0 or later. Execute after installation.

1. clone this repository
1. `cd focuslight`
1. install dependencies: `bundle install`
1. initialize database: `bundle exec rake init`
1. execute: `bundle exec foreman start`

See `http://localhost:5125/`

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
FLOAT_SUPPORT=n
# MYSQL=n
# RRDCACHED=n
# MOUNT=/
```

## Switch from GrowthForecast

1. Copy GrowthForecast's `datadir` directory (and its contents) to `./data` (or where you specified)
1. Execute Focuslight

## TODO

* Merge GrowthForecast's commits after Jan 09, 2014
  * api endpoint link label
* MySQL support
* RRDCached support
* Front proxies and source address restrictions
* HTTP API mount point support
* Daemonize support
* Installation from rubygems.org
* Add tests, and tests, and more tests

## Imcompatible Features

Focuslight has following incompatibilitie with GrowthForecast as specifications.

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
