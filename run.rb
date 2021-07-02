# frozen_string_literal: true

require_relative 'bilibili/login'
require_relative 'utils/http'

http_client = BiliHttp::HttpClient.new
login = Bilibili::Login.new(http_client)
login.login
user = login.login_user_info
puts user.to_json
