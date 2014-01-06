class Report < ActiveRecord::Base
	belongs_to :report_group
	has_many :report_versions

	def latest_version
		self.report_versions.order("version DESC").first
	end

end
