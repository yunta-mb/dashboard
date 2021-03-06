require 'eventmachine'
require 'faye'
require 'rack'
require 'thin'

class FayeLog

	def incoming(message, callback)
		puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " <"
                #p message
		callback.call(message)
	end

	def outgoing(message, callback)
		puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + " >"
                #p message
		callback.call(message)
	end

end

subscriptions = {}

Faye::WebSocket.load_adapter('thin')
app = Faye::RackAdapter.new(mount: '/live', timeout: 25, extensions: [FayeLog.new])
run app
