# frozen_string_literal: true

require_relative 'bilibili-console/login'
require_relative 'bilibili-console/http/http'

http_client = BiliHttp::HttpClient.new
login = Bilibili::Login.new(http_client)
success = login.login
unless success.nil?
  user = login.login_user_info
  puts user.to_json
end
