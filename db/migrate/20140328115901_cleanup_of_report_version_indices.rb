class CleanupOfReportVersionIndices < ActiveRecord::Migration
	def change
		add_index :report_versions, [:report_id, :created_at], order: { created_at: :desc }
		remove_index :report_versions, :report_id
	end
end
