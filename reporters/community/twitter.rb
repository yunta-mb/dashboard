#!/usr/bin/env ruby

require 'twitter'
require 'json'
require 'twitter'
require 'date'

require_relative 'config.rb'

def init_count(keyword, max_id)
	client = Twitter::REST::Client.new(TWITTER)
	_tweets_id = Array.new()
	client.search(keyword, :max_id => max_id-1).each {|tweet|
		_tweets_id.push tweet.id
	}
	{:counter => _tweets_id.count, :max_id => _tweets_id.min}
end

#function return total number posts with 
## this is return only posts from last week !!
def total_count(keyword)
	client = Twitter::REST::Client.new(TWITTER)
	# get latest post's id with mentioned keyword
	first_id = client.search(keyword).first.id
	# get number of posts from first page
	res = init_count(keyword, first_id + 1)
	total = res[:counter]
	# follow counting posts on rest of pages
	while (res[:counter] > 0)
		res = init_count(keyword, res[:max_id])
		total += res[:counter]
	end
	puts "Total tweets: " + total.to_s
	total
end

# show recent post from - default - last 4 hours
def show_recent_posts(keyword, hours = 4)
	client = Twitter::REST::Client.new(TWITTER)
	puts past = Time.now - (60*60*hours)
	tweets = Array.new
	client.search(keyword).each do |tweet|
		if tweet.created_at >= past
			puts tweet.text
			tweets.push tweet.created_at
		else
			return
		end
	end
end

total_count("#")
# show_recent_posts("#", 24)

