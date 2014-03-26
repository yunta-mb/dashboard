class Report < ActiveRecord::Base
	belongs_to :report_group
	has_many :report_versions

	def latest_version
		self.report_versions.order("version DESC").first
	end

	def version_at(timestamp)
#		ret = self.report_versions.where("created_at <= ?",timestamp).order("version DESC").first
		ret = ReportVersion.where('report_id = ? AND created_at = (SELECT max(created_at) FROM report_versions rv2 WHERE rv2.report_id = ? AND (created_at <= ?))',self.id, self.id, timestamp).order("version DESC").first
		ret or self.report_versions.order("version ASC").first
	end

end
