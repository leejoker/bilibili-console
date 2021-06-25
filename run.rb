# frozen_string_literal: true

require_relative 'bilibili/login'

login = BiliHttp::Login.new
login.login
