require_relative 'config.rb'

require 'rubygems'
require 'bundler/setup'

require 'rest_client'
require 'json'
require 'erb'
require 'coffee-script'
#require 'awesome_print'
require 'sass'
require 'sass/exec'

# fake sprockets for skim
module Sprockets 
	def self.register_engine(*_); end
	def self.append_path(*_); end
end
require 'skim'

if ARGV.size != 2 
	puts "update_projector.rb REPORT_ID PROJECTOR_FILE_NAME"
	exit 1
end

$server = RestClient::Resource.new(SERVER_URL)

def erb(file_name)
	ERB.new(open(file_name).read).result(binding)
end

def sass(file_name)
	Sass.compile(erb(file_name), syntax: :sass)
end


def skim(file_name)
	p x = Skim::Template.new { erb(file_name) }.render({})
	x
end



puts projector = CoffeeScript.compile(erb(ARGV[1]))

puts "Uploaded projector, new report version: %i"%JSON.parse($server["/reports/%i/versions.json"%ARGV[0]].post(content: JSON.dump({ projector: projector })), symbolize_names: true)[:version]


