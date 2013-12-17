class Report < ActiveRecord::Base
	belongs_to :report_group
	has_many :report_versions
end
