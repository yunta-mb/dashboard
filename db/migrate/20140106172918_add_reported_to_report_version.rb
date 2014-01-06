class AddReportedToReportVersion < ActiveRecord::Migration
	def change
		add_column :report_versions, :reported, :boolean, default: false
	end
end
