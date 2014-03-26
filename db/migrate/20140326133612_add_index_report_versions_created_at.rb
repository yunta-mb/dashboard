class AddIndexReportVersionsCreatedAt < ActiveRecord::Migration
	def up
		add_index :report_versions, :created_at
	end
end
