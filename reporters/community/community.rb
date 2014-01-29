require './config.rb'

require 'rubygems'
require 'bundler/setup'

require 'rest_client'
require 'json'
#require 'awesome_print'
require 'benchmark'

require_relative 'twitter.rb'


$server = RestClient::Resource.new(SERVER_URL)

#report = JSON.parse($server["/reports/%i/versions/latest.json"%COMMUNITY_REPORT_ID].get, symbolize_names: true)[:data]
report = { }


loop {

	puts Benchmark.measure {
		report[:recent_activity] = show_recent_posts(TWITTER_TAG+" -rt", 4).map { |tweet| 
			tweet[:timestamp] = tweet[:timestamp].strftime("%Y-%m-%dT%H:%M:%SZ")
			tweet[:system] = "twitter"
			tweet[:id] = tweet[:url]
			tweet[:magnitude] = 1+tweet[:retweet_count]
			tweet
		}
	}

	puts "Uploaded report: %i"%JSON.parse($server["/reports/%i/versions.json"%COMMUNITY_REPORT_ID].post(content: JSON.dump({ data: report })), symbolize_names: true)[:version]

	sleep 10
}

