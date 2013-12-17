class CreateReportGroups < ActiveRecord::Migration
  def change
    create_table :report_groups do |t|
      t.references :parent, index: true
      t.text :name

      t.timestamps
    end
  end
end
