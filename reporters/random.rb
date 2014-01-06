require './reporters/config.rb'

require 'rest_client'
require 'json'
#require 'awesome_print'

$server = RestClient::Resource.new(SERVER_URL)

loop {
	data = JSON.parse($server["/reports/2/versions/latest.json"].get, symbolize_names: true)[:data]
#	data = [{ id: 0, value: rand }]
	data << { id: data[-1][:id] + 1, value: rand }
	data.shift if data.size > 10
	puts "Uploaded report: %i"%JSON.parse($server["/reports/2/versions.json"].post(content: JSON.dump({ data: data })), symbolize_names: true)[:version]
	sleep 1
}

