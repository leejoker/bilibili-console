# frozen_string_literal: true

require_relative 'bilibili/login'

login = Bilibili::Login.new
login.login
user = login.login_user_info
puts user.to_json
