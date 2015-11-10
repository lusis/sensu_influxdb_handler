require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'em-http-request'
require 'eventmachine'
require 'json'

module Sensu::Extension
  class InfluxDB < Handler
    def name
      definition[:name]
    end

    def definition
      {
        type: 'extension',
        name: 'influxdb'
      }
    end

    def description
      'Outputs metrics to InfluxDB'
    end

    def post_init()
      # NOTE: Making sure we do not get any data from the Main
    end

    def run(event_data)
      event = parse_event(event_data)
      conf = parse_settings()

      # init event and check data
      body = []
      host = event['client']['name']
      event['check']['influxdb']['database'] ||= conf['database']
      protocol = conf.fetch('ssl_enable', false) ? 'https' : 'http'

      event['check']['output'].split(/\n/).each do |line|
        key, value, time = line.split(/\s+/)
        values = "value=#{value.to_f}"

        if event['check']['duration']
          values += ",duration=#{event['check']['duration'].to_f}"
        end

        if conf['strip_metric'] == 'host'
          key = slice_host(key, host)
        elsif conf['strip_metric']
          key.gsub!(/^.*#{conf['strip_metric']}\.(.*$)/, '\1')
        end

        # Avoid things break down due to comma in key name
        # TODO : create a key_clean def to refactor this
        key.gsub!(',', '\,')

        # This will merge : default conf tags < check embedded tags < sensu client/host tag
        tags = conf.fetch(:tags, {}).merge(event['check']['influxdb']['tags']).merge({'host' => host})
        tags.each do |tag, val|
          key += ",#{tag}=#{val}"
        end

        body += [[key, values, time.to_i].join(' ')]
      end

      # TODO: adding rp & consistency options
      EventMachine::HttpRequest.new("#{ protocol }://#{ conf['host'] }:#{ conf['port'] }/write?db=#{ event['check']['influxdb']['database'] }&precision=#{ event['check']['time_precision'] }&u=#{ conf['user'] }&p=#{ conf['password'] }").post :head => { 'content-type' => 'application/x-www-form-urlencoded' }, :body => body.join("\n") + "\n"

      yield('', 0)
    end

    def stop
      true
    end

    private
    def parse_event(event_data)
      begin
        event = JSON.parse(event_data)

        # override default values for non-existing keys
        event['check']['time_precision'] ||= 's' # n, u, ms, s, m, and h (default community plugins use standard epoch date)
        event['check']['influxdb'] ||= {}
        event['check']['influxdb']['tags'] ||= {}
        event['check']['influxdb']['database'] ||= nil

      rescue => e
        puts "Failed to parse event data: #{e}"
      end
      return event
    end

    def parse_settings()
      begin
        settings = {
          'database' => @settings['influxdb']['database'],
          'host' => @settings['influxdb']['host'],
          'password' => @settings['influxdb']['password'],
          'port' => @settings['influxdb']['port'],
          'tags' => @settings['influxdb']['tags'],
          'ssl_enable' => @settings['influxdb']['ssl_enable'],
          'strip_metric' => @settings['influxdb']['strip_metric'],
          'timeout' => @settings['influxdb']['timeout'],
          'user' => @settings['influxdb']['user']
        }
      rescue => e
        puts "Failed to parse InfluxDB settings #{e}"
      end
      return settings
    end

    def slice_host(slice, prefix)
      prefix.chars.zip(slice.chars).each do |char1, char2|
        if char1 != char2
          break
        end
        slice.slice!(char1)
      end
      if slice.chars.first == '.'
        slice.slice!('.')
      end
      return slice
    end
  end
end
