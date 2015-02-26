class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.



	protect_from_forgery with: :exception
	before_filter :set_current_user

	private
	
	def set_current_user
		@current_user = if File.exists?("fake_auth_user")
			                open("fake_auth_user") { |f| f.read }.strip
		                else
			                Base64.decode64(request.env["HTTP_AUTHORIZATION"].split(" ")[1]).split(":")[0].encode('UTF-8')
		                end
		Thread.current[:current_user] = @current_user
	end
end
