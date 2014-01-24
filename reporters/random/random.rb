require_relative '../config.rb'

require 'rest_client'
require 'json'
#require 'awesome_print'

$server = RestClient::Resource.new(SERVER_URL)

data = JSON.parse($server["/reports/1/versions/latest.json"].get, symbolize_names: true)[:data]
#data = { sequence: [{ id: 0, value: rand }] }

loop {
	data[:sequence] << { id: data[:sequence][-1][:id] + 1, value: rand }
	data[:sequence].shift if data[:sequence].size > 40
	puts "Uploaded report: %i"%JSON.parse($server["/reports/1/versions.json"].post(content: JSON.dump({ data: data })), symbolize_names: true)[:version]
	sleep 1
}

