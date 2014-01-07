require './config/environment.rb'

require 'faye'
require 'eventmachine'

EM.run {
	faye = Faye::Client.new(SERVER_URL)

	faye.subscribe("/ping") { |message|
		p "got ping", message
	}

}

