class CreateIndexOnReportVersionReportIdVersion < ActiveRecord::Migration
  def change
    add_index :report_versions, [:report_id, :version], order: { version: :desc }
  end
end
