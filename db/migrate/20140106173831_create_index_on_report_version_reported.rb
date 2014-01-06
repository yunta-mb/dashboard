class CreateIndexOnReportVersionReported < ActiveRecord::Migration
	def change
		add_index :report_versions, :reported, where: "reported = false"
	end
end
