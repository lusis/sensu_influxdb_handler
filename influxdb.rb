require "rubygems" if RUBY_VERSION < '1.9.0'
require "em-http"
require "eventmachine"
require "json"

module Sensu::Extension
  class InfluxDB < Handler
    def name
      definition[:name]
    end

    def definition
      {
        type: "extension",
        name: "influxdb"
      }
    end

    def description
      "Outputs metrics to InfluxDB"
    end

    def post_init()
      # NOTE: Making sure we do not get any data from the Main
    end

    def run(event_data)
      data = parse_event(event_data)
      points = Array.new()

      data["output"].split(/\n/).each do |line|
        key, value, time = line.split(/\s+/)

        if @settings["influxdb"]["strip_metric"] == "host"
          key = slice_host(key, data["host"])
        elsif @settings["influxdb"]["strip_metric"]
          key.gsub!(/^.*#{@settings['influxdb']['strip_metric']}\.(.*$)/, '\1')
        end

        # TODO: Try and sanitise the time
        points.push([time.to_i, data["host"], key, value])
      end

      body = [{
        "name" => data["series"],
        "columns" => ["time", "host", "metric", "value"],
        "points" => points
      }]

      settings = parse_settings()

      EventMachine::HttpRequest.new("http://#{ settings["host"] }:#{ settings["port"] }/db/#{ settings["database"] }/series?u=#{ settings["user"] }&p=#{ settings["password"] }").post :head => { "content-type" => "application/x-www-form-urlencoded" }, :body => body.to_json
    end

    private
      def parse_event(event_data)
        begin
          event = JSON.parse(event_data)
          data = {
            "duration" => event["check"]["duration"],
            "host" => event["client"]["name"],
            "output" => event["check"]["output"],
            "series" => event["check"]["name"],
            "timestamp" => event["check"]["issued"]
          }
        rescue => e
          puts "Failed to parse event data"
        end
      end

      def parse_settings()
        begin
          settings = {
            "database" => @settings["influxdb"]["database"],
            "host" => @settings["influxdb"]["host"],
            "password" => @settings["influxdb"]["password"],
            "port" => @settings["influxdb"]["port"],
            "strip_metric" => @settings["influxdb"]["strip_metric"],
            "timeout" => @settings["influxdb"]["timeout"],
            "user" => @settings["influxdb"]["user"]
          }
        rescue => e
          puts "Failed to parse InfluxDB settings"
        end
        return settings
      end

      def slice_host(slice, prefix)
        prefix.chars().zip(slice.chars()).each do | char1, char2 |
          slice.slice!(char1)
        end
        if slice.chars.first == "."
          slice.slice!(char1)
        end
        return slice
      end
  end
end
