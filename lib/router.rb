require 'eventmachine'
require 'faye'
require 'rack'
require 'thin'

class FayeLog

	def incoming(message, callback)
		puts "<"
		callback.call(message)
	end

	def outgoing(message, callback)
		puts ">"
		callback.call(message)
	end

end


Faye::WebSocket.load_adapter('thin')
app = Faye::RackAdapter.new(mount: '/live', timeout: 25, extensions: [FayeLog.new])
run app
