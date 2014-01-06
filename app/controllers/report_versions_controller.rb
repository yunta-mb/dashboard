class ReportVersionsController < ApplicationController
	
	skip_before_action :verify_authenticity_token, only: [:create]


	def show
		report = Report.find(params[:report_id])
		report_version = if params[:id] != "latest"
			                 report.report_versions.find_by(version: params[:id])
		                 else
			                 report.report_versions.order("version DESC").first
		                 end
		render json: report_version
	end


	def create
		content = JSON.parse(params[:content], symbolize_names: true)
		report_version = ReportVersion.new
		report_version.report = Report.find(params[:report_id])
		Report.transaction {
			latest_report_version = report_version.report.latest_version
			latest_report_version_version = (latest_report_version ? latest_report_version.version : 1)
			report_version.version = latest_report_version_version + 1
			report_version.data = (content[:data] or (latest_report_version ? latest_report_version.data : nil))
			report_version.projector = (content[:projector] or (latest_report_version ? latest_report_version.projector : nil))
			report_version.save
		}
		render json: { version: report_version.version }
	end
	
end
