require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'influxdb'
require 'timeout'

module Sensu::Extension

  class Influx < Handler

    def name
      'influx'
    end

    def description
      'outputs metrics to InfluxDB'
    end

    def post_init
      @influxdb = InfluxDB::Client.new settings['influx']['database'], :host => settings['influx']['host'], :port => settings['influx']['port'], :username => settings['influx']['user'], :password => settings['influx']['password']
      @timeout = @settings['influx']['timeout'] || 15
      @series_per_metric = @settings['influx']['series_per_metric'] || false
    end

    def run(event)
      begin
        event = Oj.load(event)
        host = event[:client][:name]
        series = event[:check][:name]
        timestamp = event[:check][:issued]
        duration = event[:check][:duration]
        output = event[:check][:output]
      rescue => e
        @logger.error("InfluxDB: Error setting up event object - #{e.backtrace.to_s}")
      end

      begin
        points = []
        output.split(/\n/).each do |line|
          @logger.debug("Parsing line: #{line}")
	  k,v,t = line.split(/\s+/)
          v = v.match('\.').nil? ? Integer(v) : Float(v) rescue v.to_s
          k.gsub!(/^.*#{@settings['influx']['strip_metric']}\.(.*$)/, '\1') if @settings['influx']['strip_metric']
          points << {:time => t.to_f, :host => host, :metric => k, :value => v}
        end
      rescue => e
        @logger.error("InfluxDB: Error parsing output lines - #{e.backtrace.to_s}")
        @logger.error("InfluxDB: #{output}")
      end

      begin
        if ! @series_per_metric
          @influxdb.write_point(series, points, true)
        else
          points.each do |p|
            series = p[:metric]
            p.delete(:metric)
            @influxdb.write_point(series, p, true)
          end
        end
      rescue => e
        @logger.error("InfluxDB: Error posting event - #{e.backtrace.to_s}")
      end
      yield("InfluxDB: Handler finished", 0)
    end

  end
end
