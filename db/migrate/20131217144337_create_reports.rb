class CreateReports < ActiveRecord::Migration
  def change
    create_table :reports do |t|
      t.text :name
      t.references :report_group, index: true

      t.timestamps
    end
  end
end
