class ReportVersion < ActiveRecord::Base
	belongs_to :report
	serialize :data, JSON
	serialize :projector, JSON
end

