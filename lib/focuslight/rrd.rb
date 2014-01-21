# -*- coding: utf-8 -*-
require "focuslight"
require "focuslight/config"
require "focuslight/graph"

require "time"
require "tempfile"

require "rrd"

class Focuslight::RRD
  def initialize(args={})
    @datadir = Focuslight::Config.get(:datadir)
    # rrdcached
  end

  def rrd_create_options_long(dst)
    [
      '--step', '300',
      "DS:num:#{dst}:600:U:U",
      "DS:sub:#{dst}:600:U:U",
      'RRA:AVERAGE:0.5:1:1440', # 5mins, 5days
      'RRA:AVERAGE:0.5:6:1008', # 30mins, 21days
      'RRA:AVERAGE:0.5:24:1344', # 2hours, 112days
      'RRA:AVERAGE:0.5:288:2500', # 24hours, 500days
      'RRA:MAX:0.5:1:1440', # 5mins, 5days
      'RRA:MAX:0.5:6:1008', # 30mins, 21days
      'RRA:MAX:0.5:24:1344', # 2hours, 112days
      'RRA:MAX:0.5:288:2500', # 24hours, 500days
    ]
  end

  def rrd_create_options_short(dst)
    [
      '--step', '60',
      "DS:num:#{dst}:120:U:U",
      "DS:sub:#{dst}:120:U:U",
      'RRA:AVERAGE:0.5:1:4800', # 1min, 3days(80hours)
      'RRA:MAX:0.5:1:4800', # 1min, 3days(80hours)
    ]
  end

  def path(graph, target=:normal)
    dst = (graph.mode == 'derive' ? 'DERIVE' : 'GAUGE')
    filepath = nil
    rrdoptions = nil
    if target == :short
      filepath = File.join(@datadir, graph.md5 + '_s.rrd')
      rrdoptions = rrd_create_options_short(dst)
    else # :long
      filepath = File.join(@datadir, graph.md5 + '.rrd')
      rrdoptions = rrd_create_options_long(dst)
    end
    unless File.exists?(filepath)
      ret = RRD::Wrapper.create(filepath, *rrdoptions.map(&:to_s))
      unless ret
        # TODO: error logging / handling
        raise "RRDtool returns error to create #{filepath}, error: #{RRD::Wrapper.error}"
      end
    end
    filepath
  end

  def update(graph, target=:normal)
    file = path(graph, target)
    subtract = if target == :short
                 graph.subtract_short
               else
                 graph.subtract
               end
    options = [
      file,
      '-t', 'num:sub',
      '--', ['N', graph.number, subtract].join(':')
    ]
    ## TODO: rrdcached
    # if ( $self->{rrdcached} ) {
    #   # The caching daemon cannot be used together with templates (-t) yet.
    #   splice(@argv, 1, 2); # delete -t option
    #   unshift(@argv, '-d', $self->{rrdcached});
    # }
    ret = RRD::Wrapper.update(*options.map(&:to_s))
    unless ret
      raise "RRDtool returns error to update #{file}, error: #{RRD::Wrapper.error}"
    end
  end

  def calc_period(span, from, to)
    span ||= 'd'

    period_title = nil
    period = nil
    period_end = 'now'
    xgrid = nil

    case span
    when 'c', 'sc'
      from_time = Time.parse(from)             # from default: 8 days ago by '%Y/%m/%d %T'
      to_time = to ? Time.parse(to) : Time.now # to   default: now by '%Y/%m/%d %T'
      raise ArgumentError, "from(#{from}) is recent date than to(#{to})" if from_time > to_time
      period_title = "#{from} to #{to}"
      period = from_time.to_i
      period_end = to_time.to_i
      diff = to_time - from_time
      if diff < 3 * 60 * 60
        xgrid = 'MINUTE:10:MINUTE:20:MINUTE:10:0:%M'
      elsif diff < 4 * 24 * 60 * 60
        xgrid = 'HOUR:6:DAY:1:HOUR:6:0:%H'
      elsif diff < 14 * 24 * 60 * 60
        xgrid = 'DAY:1:DAY:1:DAY:2:86400:%m/%d'
      elsif diff < 45 * 24 * 60 * 60
        xgrid = 'DAY:1:WEEK:1:WEEK:1:0:%F'
      else
        xgrid = 'WEEK:1:MONTH:1:MONTH:1:2592000:%b'
      end
    when 'h', 'sh'
      period_title = (span == 'h' ? 'Hour (5min avg)' : 'Hour (1min avg)')
      period = -1 * 60 * 60 * 2
      xgrid = 'MINUTE:10:MINUTE:20:MINUTE:10:0:%M'
    when 'n', 'sn'
      period_title = (span == 'n' ? 'Half Day (5min avg)' : 'Half Day (1min avg)')
      period = -1 * 60 * 60 * 14
      xgrid = 'MINUTE:60:MINUTE:120:MINUTE:120:0:%H %M'
    when 'w'
      period_title = 'Week (30min avg)'
      period = -1 * 60 * 60 * 24 * 8
      xgrid = 'DAY:1:DAY:1:DAY:1:86400:%a'
    when 'm'
      period_title = 'Month (2hour avg)'
      period = -1 * 60 * 60 * 24 * 35
      xgrid = 'DAY:1:WEEK:1:WEEK:1:604800:Week %W'
    when 'y'
      period_title = 'Year (1day avg)'
      period = -1 * 60 * 60 * 24 * 400
      xgrid = 'WEEK:1:MONTH:1:MONTH:1:2592000:%b'
    when '3d', 's3d'
      period_title = (span == '3d' ? '3 Days (5min avg)' : '3 Days (1min avg)')
      period = -1 * 60 * 60 * 24 * 3
      xgrid = 'HOUR:6:DAY:1:HOUR:6:0:%H'
    when '8h', 's8h'
      period_title = (span == '8h' ? '8 Hours (5min avg)' : '8 Hours (1min avg)')
      period = -1 * 8 * 60 * 60
      xgrid = 'MINUTE:30:HOUR:1:HOUR:1:0:%H:%M'
    when '4h', 's4h'
      period_title = (span == '4h' ? '4 Hours (5min avg)' : '4 Hours (1min avg)')
      period = -1 * 4 * 60 * 60
      xgrid = 'MINUTE:30:HOUR:1:MINUTE:30:0:%H:%M'
    else # 'd' or 'sd' ?
      period_title = (span == 'sd' ? 'Day (1min avg)' : 'Day (5min avg)')
      period = -1 * 60 * 60 * 33 # 33 hours
      xgrid = 'HOUR:1:HOUR:2:HOUR:2:0:%H'
    end

    return period_title, period, period_end, xgrid
  end

  def graph(datas, args)
    datas = [datas] unless datas.is_a?(Array)
    a_gmode = args[:gmode]
    span = args.fetch('t', 'd')
    from = args[:from]
    to = args[:to]
    width = args.fetch(:width, 390)
    height = args.fetch(:height, 110)

    period_title, period, period_end, xgrid = calc_period(span, from, to)

    if datas.size == 1 && a_gmode == 'subtract'
      period_title = "[subtract] #{period_title}"
    end

    tmpfile = Tempfile.new(["", ".png"]) # [basename_prefix, suffix]
    rrdoptions = [
      tmpfile.path,
      '-w', width,
      '-h', height,
      '-a', 'PNG',
      '-l', 0, #minimum
      '-u', 2, #maximum
      '-x', (args[:xgrid].empty? ? xgrid : args[:xgrid]),
      '-s', period,
      '-e', period_end,
      '--slope-mode',
      '--disable-rrdtool-tag',
      '--color', 'BACK#' + args[:background_color].to_s.upcase,
      '--color', 'CANVAS#' + args[:canvas_color].to_s.upcase,
      '--color', 'FONT#' + args[:font_color].to_s.upcase,
      '--color', 'FRAME#' + args[:frame_color].to_s.upcase,
      '--color', 'AXIS#' + args[:axis_color].to_s.upcase,
      '--color', 'SHADEA#' + args[:shadea_color].to_s.upcase,
      '--color', 'SHADEB#' + args[:shadeb_color].to_s.upcase,
      '--border', args[:border].to_s.upcase
    ]
    rrdoptions.push('-y', args[:ygrid]) unless args[:ygrid].empty?
    rrdoptions.push('-t', period_title.to_s.dup) unless args[:notitle]
    rrdoptions.push('--no-legend') unless args[:legend]
    rrdoptions.push('--only-graph') if args[:graphonly]
    rrdoptions.push('--logarithmic') if args[:logarithmic]

    rrdoptions.push('--font', "AXIS:8:")
    rrdoptions.push('--font', "LEGEND:8:")

    rrdoptions.push('-u', args[:upper_limit]) if args[:upper_limit]
    rrdoptions.push('-l', args[:lower_limit]) if args[:lower_limit]
    rrdoptions.push('-r') if args[:rigid]

    defs = []
    datas.each_with_index do |data, i|
      gmode = data.c_gmode ? data.c_gmode : a_gmode
      type  = data.c_type ? data.c_type : (gmode == 'subtract' ? data.stype : data.type)
      gdata =  (gmode == 'subtract' ? 'sub' : 'num')
      llimit = (gmode == 'subtract' ? data.sllimit : data.llimit)
      ulimit = (gmode == 'subtract' ? data.sulimit : data.ulimit)
      stack = (data.stack && i > 0 ? ':STACK' : '')
      file = (span =~ /^s/ ? path(data, :short) : path(data, :long))
      unit = (data.unit || '').gsub('%', '%%')

      rrdoptions.push(
        'DEF:%s%dt=%s:%s:AVERAGE' % [gdata, i, file, gdata],
        'CDEF:%s%d=%s%dt,%s,%s,LIMIT,%d,%s' % [gdata, i, gdata, i, llimit, ulimit, data.adjustval, data.adjust],
        '%s:%s%d%s:%s %s' % [type, gdata, i, data.color, _escape(data.graph), stack],
        'GPRINT:%s%d:LAST:Cur\: %%4.1lf%%s%s' % [gdata, i, unit],
        'GPRINT:%s%d:AVERAGE:Avg\: %%4.1lf%%s%s' % [gdata, i, unit],
        'GPRINT:%s%d:MAX:Max\: %%4.1lf%%s%s' % [gdata, i, unit],
        'GPRINT:%s%d:MIN:Min\: %%4.1lf%%s%s\l' % [gdata, i, unit],
        'VDEF:%s%dcur=%s%d,LAST' % [gdata, i, gdata, i],
        'PRINT:%s%dcur:%%.8lf' % [gdata, i],
        'VDEF:%s%davg=%s%d,AVERAGE' % [gdata, i, gdata, i],
        'PRINT:%s%davg:%%.8lf' % [gdata, i],
        'VDEF:%s%dmax=%s%d,MAXIMUM' % [gdata, i, gdata, i],
        'PRINT:%s%dmax:%%.8lf' % [gdata, i],
        'VDEF:%s%dmin=%s%d,MINIMUM' % [gdata, i, gdata, i],
        'PRINT:%s%dmin:%%.8lf' % [gdata, i],
      )
      defs << ('%s%d' % [gdata, i])
    end

    if args[:sumup]
      sumup = [ defs.shift ]
      unit = datas.first.unit.gsub('%', '%%')
      defs.each do |d|
        sumup.push(d, '+')
      end
      rrdoptions.push(
        'CDEF:sumup=%s' % [ sumup.join(',') ],
        'LINE0:sumup#cccccc:total',
        'GPRINT:sumup:LAST:Cur\: %%4.1lf%%s%s' % [unit],
        'GPRINT:sumup:AVERAGE:Avg\: %%4.1lf%%s%s' % [unit],
        'GPRINT:sumup:MAX:Max\: %%4.1lf%%s%s' % [unit],
        'GPRINT:sumup:MIN:Min\: %%4.1lf%%s%s\l' % [unit],
        'VDEF:sumupcur=sumup,LAST',
        'PRINT:sumupcur:%%.8lf',
        'VDEF:sumupavg=sumup,AVERAGE',
        'PRINT:sumupavg:%%.8lf',
        'VDEF:sumupmax=sumup,MAXIMUM',
        'PRINT:sumupmax:%%.8lf',
        'VDEF:sumupmin=sumup,MINIMUM',
        'PRINT:sumupmin:%%.8lf',
      )
    end

    ret = RRD::Wrapper.graph(*rrdoptions.map(&:to_s))
    unless ret
      tmpfile.close!
      raise "RRDtool returns error to draw graph, error: #{RRD::Wrapper.error}"
    end

    # Cannot get last PRINT return value, set of [current,avg,max,min] of each data source
    # This makes 'summary' API not supported

    graph_img = IO.binread(tmpfile.path); # read as binary
    tmpfile.delete

    [
      "/var/folders/tl/xtb7dnc132nggd6hs83y58h40000gq/T/20140117-86285-1igjvvh.png",
      "-w", 390,
      "-h", 110,
      "-a", "PNG",
      "-l", 0,
      "-u", 2,
      "-x", "HOUR:1:HOUR:2:HOUR:2:0:%H",
      "-s", -118800,
      "-e", "now",
      "--slope-mode",
      "--disable-rrdtool-tag",
      "--color", "BACK#F3F3F3", "--color", "CANVAS#FFFFFF", "--color", "FONT#000000",
      "--color", "FRAME#000000", "--color", "AXIS#000000", "--color", "SHADEA#CFCFCF",
      "--color", "SHADEB#9E9E9E",
      "--border", "3",
      "-t", "Day (1min avg)",
      "--no-legend",
      "--font", "AXIS:8:",
      "--font", "LEGEND:8:",
      "DEF:num0t=./data/c4ca4238a0b923820dcc509a6f75849b.rrd:num:AVERAGE",
      "CDEF:num0=num0t,-1000000000.0,1.0e+15,LIMIT,1,*",
      "AREA:num0:one",
      "GPRINT:num0:LAST:Cur\\: %4.1lf%s",
      "GPRINT:num0:AVERAGE:Avg\\: %4.1lf%s",
      "GPRINT:num0:MAX:Max\\: %4.1lf%s",
      "GPRINT:num0:MIN:Min\\: %4.1lf%s\\l",
      "VDEF:num0cur=num0,LAST",
      "PRINT:num0cur:%.8lf",
      "VDEF:num0avg=num0,AVERAGE",
      "PRINT:num0avg:%.8lf",
      "VDEF:num0max=num0,MAXIMUM",
      "PRINT:num0max:%.8lf",
      "VDEF:num0min=num0,MINIMUM",
      "PRINT:num0min:%.8lf"
    ]

    graph_img
  end

  def export(datas, args)
    datas = [datas] unless datas.is_a?(Array)
    a_gmode = args[:gmode]
    span = args.fetch(:t, 'd')
    from = args[:from]
    to = args[:to]
    width = args.fetch(:width, 390)
    cf = args[:cf]

    period_title, period, period_end, xgrid = calc_period(span, from, to)

    rrdoptions = [
      '-m', width,
      '-s', period,
      '-e', period_end
    ]

    rrdoptions.push('--step', args[:step]) if args[:step]

    defs = []
    datas.each_with_index do |data, i|
      gmode = data.c_gmode ? data.c_gmode : a_gmode
      type  = data.c_type ? data.c_type : (gmode == 'subtract' ? data.stype : data.type)
      gdata =  (gmode == 'subtract' ? 'sub' : 'num')
      llimit = (gmode == 'subtract' ? data.sllimit : data.llimit)
      ulimit = (gmode == 'subtract' ? data.sulimit : data.ulimit)
      stack = (data.stack && i > 0 ? ':STACK' : '')
      file = (span =~ /^s/ ? path(data, :short) : path(data, :long))

      rrdoptions.push(
        'DEF:%s%dt=%s:%s:%s' % [gdata, i, file, gdata, cf],
        'CDEF:%s%d=%s%dt,%s,%s,LIMIT,%d,%s' % [gdata, i, gdata, i, llimit, ulimit, data.dadjustval, data.adjust],
        'XPORT:%s%d:%s' % [gdata, i, _escape(data.graph)]
      )
      defs << ('%s%d' % [gdata, i])
    end

    if args[:sumup]
      sumup = [ defs.shift ]
      defs.each do |d|
        sumup.push(d, '+')
      end
      rrdoptions.push(
        'CDEF:sumup=%s' % [sumup.join(',')],
        'XPORT:sumup:total'
      )
    end

    ret = RRD::Wrapper.xport(*rrdoptions.map(&:to_s))
    unless ret
      raise "RRDtool returns error to xport, error: #{RRD::Wrapper.error}"
    end
    ### copied from RRD::Wrapper spec
    # values = RRD::Wrapper.xport("--start", "1266933600", "--end", "1266944400", "DEF:xx=#{RRD_FILE}:cpu0:AVERAGE", "XPORT:xx:Legend 0")
    # values[0..-2].should == [["time", "Legend 0"], [1266933600, 0.0008], [1266937200, 0.0008], [1266940800, 0.0008]]
    cols_row = ret.shift

    column_names = cols_row[1..-1] # cols_row[0] == 'time'
    columns = column_names.length
    start_timestamp = ret.first.first
    end_timestamp = ret.last.first
    step = ret[1].first - ret[0].first

    rows = []
    ret.each do |values|
      rows << values[1..-1]
    end

    {
      'start_timestamp' => start_timestamp,
      'end_timestamp' => end_timestamp,
      'step' => step,
      'columns' => columns,
      'column_names' => column_names,
      'rows' => rows,
    }
  end

  def remove(graph)
    [File.join(@datadir, graph.md5 + '.rrd'), File.join(@datadir, graph.md5 + '_s.rrd')].each do |file|
      begin
        File.delete(file)
      rescue => e
        # ignore NOSUCHFILE or others
      end
    end
  end

  def _escape(str)
    str.gsub(':', '\:')
  end
end
