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

app.on(:subscribe) { |client_id, channel|
	(subscriptions[channel] ||= []) << client_id
	message = { event: "subscribe", channel: channel, client_id: client_id }
	message[:subscriptions] = subscriptions if channel == "/events/subscriptions"
	app.get_client.publish("/events/subscriptions", message)
}

app.on(:unsubscribe) { |client_id, channel|
	subscriptions[channel].delete(client_id)
	app.get_client.publish("/events/subscriptions", event: "unsubscribe", channel: channel, client_id: client_id)
	subscriptions.delete(channel) if subscriptions[channel].size == 0
}

run app
