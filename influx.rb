#!/usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'influxdb'

class Influx < Sensu::Handler
  def filter; end

  def handle
    @influxdb = InfluxDB::Client.new settings['influx']['database'], :host => settings['influx']['host'], :port => settings['influx']['port'], :username => settings['influx']['user'], :password => settings['influx']['password']
    @event['check']['output'].split("\n").each do |line|
      n, v, _ = line.split(/\s+/)
      if settings['influx']['strip_metric']
        n.gsub!(/^.*#{settings['influx']['strip_metric']}\.(.*$)/, '\1')
      end
      @influxdb.write_point(@event['check']['name'], {:host => @event['client']['name'], :metric => n, :value => v, :duration => @event['check']['duration']})
    end
  end
end
