class ReportsController < ApplicationController

	skip_before_action :verify_authenticity_token, only: [:create]

	def create
		report = Report.new
		report.name = params[:name]
		report.priority = params[:priority]
		report.save
		Report.connection.instance_variable_get(:@connection).exec("NOTIFY data_change")
		respond_to { |format|
			format.json { render json: report }
		}
	end

end
