class AddHiddenToReport < ActiveRecord::Migration
	def change
		add_column :reports, :hidden, :boolean, default: false
	end
end
