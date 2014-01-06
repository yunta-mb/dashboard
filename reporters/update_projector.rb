require './reporters/config.rb'

require 'rest_client'
require 'json'
require 'coffee-script'
#require 'awesome_print'

if ARGV.size != 2 
	puts "update_projector.rb REPORT_ID PROJECTOR_FILE_NAME"
	exit 1
end

$server = RestClient::Resource.new(SERVER_URL)

p projector = CoffeeScript.compile(open(ARGV[1]))
puts "Uploaded projector, new report version: %i"%JSON.parse($server["/reports/%i/versions.json"%ARGV[0]].post(content: JSON.dump({ projector: projector })), symbolize_names: true)[:version]


