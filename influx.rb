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
          k.gsub!(/^.*#{@settings['influx']['strip_metric']}\.(.*$)/, '\1') if @settings['influx']['strip_metric']
          points << {:time => t.to_f, :host => host, :metric => k, :value => v}
        end
      rescue => e
        @logger.error("InfluxDB: Error parsing output lines - #{e.backtrace.to_s}")
        @logger.error("InfluxDB: #{output}")
      end

      begin
        @influxdb.write_point(series, points, true)
      rescue => e
        @logger.error("InfluxDB: Error posting event - #{e.backtrace.to_s}")
      end
      yield("InfluxDB: Handler finished", 0)
    end

  end
end
