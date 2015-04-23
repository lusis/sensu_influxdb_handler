require "rubygems" if RUBY_VERSION < '1.9.0'
require "em-http-request"
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
      data["output"].split(/\n/).each do |line|
        key, value, time = line.split(/\s+/)

        if @settings["influxdb"]["strip_metric"] == "host"
          key = slice_host(key, data["host"])
        elsif @settings["influxdb"]["strip_metric"]
          key.gsub!(/^.*#{@settings['influxdb']['strip_metric']}\.(.*$)/, '\1')
        end

        body = [{
          "name" => key.gsub!('-',''),
          "columns" => ["time", "value"],
          "points" => [[time.to_f, value.to_f]]
        }]

        settings = parse_settings()
        database = data["database"]
  
        protocol = "http"
        if settings["ssl_enable"]
          protocol = "https"
        end
        
        EventMachine::HttpRequest.new("#{ protocol }://#{ settings["host"] }:#{ settings["port"] }/db/#{ database }/series?u=#{ settings["user"] }&p=#{ settings["password"] }").post :head => { "content-type" => "application/x-www-form-urlencoded" }, :body => body.to_json

      end
    end

    private
      def parse_event(event_data)
        begin
          event = JSON.parse(event_data)
          data = {
            "database" => (event["database"].nil? ? @settings['influxdb']['database'] : event["database"]),
            "duration" => event["check"]["duration"],
            "host" => event["client"]["name"],
            "output" => event["check"]["output"],
            "series" => event["check"]["name"],
            "timestamp" => event["check"]["issued"]
          }
        rescue => e
          puts " Failed to parse event data: #{e} "
        end
        return data
      end

      def parse_settings()
        begin
          settings = {
            "database" => @settings["influxdb"]["database"],
            "host" => @settings["influxdb"]["host"],
            "password" => @settings["influxdb"]["password"],
            "port" => @settings["influxdb"]["port"],
            "ssl_enable" => @settings["influxdb"]["ssl_enable"],
            "strip_metric" => @settings["influxdb"]["strip_metric"],
            "timeout" => @settings["influxdb"]["timeout"],
            "user" => @settings["influxdb"]["user"]
          }
        rescue => e
          puts "Failed to parse InfluxDB settings #{e} "
        end
        return settings
      end

      def slice_host(slice, prefix)
        prefix.chars().zip(slice.chars()).each do | char1, char2 |
          if char1 != char2
            break
          end
          slice.slice!(char1)
        end
        if slice.chars.first == "."
          slice.slice!(".")
        end
        return slice
      end
  end
end
