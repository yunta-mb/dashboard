class AddPriorityToReports < ActiveRecord::Migration
  def change
    add_column :reports, :priority, :float
  end
end
