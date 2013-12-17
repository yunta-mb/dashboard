class CreateReportVersions < ActiveRecord::Migration
  def change
    create_table :report_versions do |t|
      t.references :report, index: true
      t.integer :version
      t.text :data
      t.text :projector

      t.timestamps
    end
  end
end
