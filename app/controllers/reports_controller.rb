class ReportsController < ApplicationController

	skip_before_action :verify_authenticity_token, only: [:create]

	def create
		report = Report.new
		report.name = params[:name]
		report.priority = params[:priority]
		report.save
		respond_to { |format|
			format.json { render json: report }
		}
	end

end
