require './config/environment.rb'

require 'faye'
require 'eventmachine'
require 'oj'
require './lib/config.rb'

def benchmark(description)
	start = Time.new
	yield
	puts "%5.2fs - %s"%[Time.new - start, description]
end


def reports
	Report.visible.order("priority NULLS LAST, name").map { |report|
		{ id: report.id, name: report.name }
	}
end




latest_reports_change_uploaded = 0
reports_version = Time.new.to_i

subscriptions = {}

EM.run {
	faye = Faye::Client.new(SERVER_URL)

	faye.subscribe("/events/subscriptions") { |message|
		if message["subscriptions"]
			subscriptions = message["subscriptions"] 
		else
			if message["event"] == "subscribe"
				(subscriptions[message["channel"]] ||= []) << message["client_id"]
			elsif message["event"] == "unsubscribe"
				subscriptions[message["channel"]].delete(message["client_id"])
				subscriptions.delete(message["channel"]) if subscriptions[message["channel"]].size == 0
			end
		end
	}

	faye.subscribe("/requests") { |message|
		#p "got reports req", message, "/client/"+message["client"]+"/reports"
		requesting = message["requesting"].split("/")[1..-1]
		response_channel = "/client/"+message["client"]+message["requesting"]
		case requesting[0]
		when "reports"
			benchmark("publishing reports list %i for client %s"%[reports_version, message["client"]]) {
				faye.publish(response_channel, { state: reports, version: reports_version })
			}
		when "report"
			benchmark("publishing report %i for client %s"%[requesting[1],message["client"]]) {
				begin
					report = Report.find(requesting[1])
				rescue ActiveRecord::RecordNotFound
					report = Report.first
				end
				
				report_version = if requesting[2] == "date" and requesting[3].to_i != 0
					                 report.version_at(Time.at(requesting[3].to_f/1000))
				                 elsif requesting[2] == "version" and requesting[3].to_i != 0
					                 report.report_versions.where(version: requesting[3].to_i).first
				                 else
					                 report.latest_version
				                 end
				if report_version
					faye.publish(response_channel, { state: { data: report_version.data, projector: report_version.projector}, version: report_version.version, timestamp: report_version.updated_at  })
				else
					faye.publish(response_channel, { state: { data: "", projector: ""}, version: -1, timestamp: "" })
				end
			}
		end
	}


	broadcast_changes = proc {
		reports_with_active_subscriptions = subscriptions.keys.select { |key| key =~ /^\/report\/(\d+)$/ }.map { |key| key.split("/")[2].to_i }
		ReportVersion.where(reported: false).group_by { |rv| rv.report_id }.each_pair { |report_id, report_versions|
			versions = report_versions.sort_by { |v| v.version }
			latest_full_update = versions.size - (versions.reverse.index { |v| true } or (versions.size-1)) - 1
			versions_to_send = versions[latest_full_update .. -1]
			versions_to_send.each { |report_version|
				if reports_with_active_subscriptions.include?(report_version.report_id)
					benchmark("publishing report version %i#%i"%[report_version.report_id, report_version.version]) {
						faye.publish("/report/"+report_id.to_s, { state: { data: report_version.data, projector: report_version.projector }, version: report_version.version, timestamp: report_version.updated_at  })
					}
				end
				report_version.reported = true
				report_version.save
			}
			versions_to_ignore = versions[0 ...  latest_full_update]
			versions_to_ignore.each { |report_version|
				report_version.reported = true
				report_version.save
			}
		}
		if (latest_reports_change = Report.visible.map { |report| [report.created_at,report.updated_at].max }.max.to_i) > latest_reports_change_uploaded
			latest_reports_change_uploaded = latest_reports_change
			reports_version += 1
			benchmark("publishing reports list %i"%[reports_version]) {
				faye.publish("/reports", { state: reports, version: reports_version })
			}
		end
	}


	Thread.new {
		ActiveRecord::Base.connection_pool.with_connection { |connection|
			connection = connection.instance_variable_get(:@connection)
			connection.exec("LISTEN data_change")
			loop {
				connection.wait_for_notify { |channel, pid, payload| 
					EM.schedule broadcast_changes
				}
			}
		}
	}


	EM.add_periodic_timer(1) {
		faye.publish("/ping",".")
	}
}

