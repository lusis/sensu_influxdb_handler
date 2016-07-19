require "sensu/extension"
require_relative "../influxdb.rb"

describe "Sensu::Extension::InfluxDB" do
  before do
    @extension = Sensu::Extension::InfluxDB.new
    @extension.settings = {
      "influxdb" => {
         "database" => "test",
         "host" => "127.0.0.1",
         "port" => 8087,
         "strip_metric" => "rpsec_strip",
         "timeout" => 15
      }
    }
  end

  it "can run, returning raw event data" do
    event = {
      "client" => {
        "name" => "rspec"
      },
      "check" => {
        "duration" => 1
        "issued" => Time.now.to_i,
        "name" => "rspec_spec",
        "output" => "rspec.test.metric #{ Random.rand(3) } #{ Time.now.to_i } ",
        "status" => 0,
      }
    }

    @extension.run(event.to_json) do |output, status|
      # TODO: Check for metric success
    end
  end
end
