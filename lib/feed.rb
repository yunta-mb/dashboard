require './config/environment.rb'

require 'faye'
require 'eventmachine'
require './lib/config.rb'

def reports
	Report.all.order("priority NULLS LAST, name").map { |report|
		{ id: report.id, name: report.name }
	}
end

EM.run {
	faye = Faye::Client.new(SERVER_URL)

	faye.subscribe("/requests") { |message|
		p "got reports req", message, "/client/"+message["client"]+"/reports"
		requesting = message["requesting"].split("/")[1..-1]
		response_channel = "/client/"+message["client"]+message["requesting"]
		p requesting
		case requesting[0]
		when "reports"
			faye.publish(response_channel, { state: reports, version: 1 })
		when "report"
			report = Report.find(requesting[1])
			report_version = report.latest_version
			faye.publish(response_channel, { state: { data: report_version.data, projector: report_version.projector }, version: report_version.version, name: report.name })
		end
	}


	EM.add_periodic_timer(1) {
		ReportVersion.where(reported: false).group_by { |rv| rv.report_id }.each_pair { |report_id, report_versions|
			report_versions.sort_by { |v| v.version }.each { |report_version|
				faye.publish("/report/"+report_id.to_s, { state: { data: report_version.data, projector: report_version.projector }, version: report_version.version })
				report_version.reported = true
				report_version.save
			}
		}
	}


	EM.add_periodic_timer(1) {
		faye.publish("/ping",".")
	}
}

