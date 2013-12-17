class ReportGroup < ActiveRecord::Base
	belongs_to :parent, class_name: ReportGroup
	has_many :children, class_name: ReportGroup, foreign_key: "parent_id"
	has_many :reports
end
