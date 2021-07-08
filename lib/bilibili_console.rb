# frozen_string_literal: true

require_relative 'bilibili_console/http/http'
require_relative 'bilibili_console/login'
require_relative 'bilibili_console/fav'

# bilibili console main class
class BilibiliConsole
  attr_accessor :http_client, :bilibili_login, :user

  def initialize
    @http_client = BiliHttp::HttpClient.new
  end

  def login
    @bilibili_login = Bilibili::Login.new(http_client)
    @bilibili_login.login
  end

  def login_user_info
    @user = @bilibili_login.login_user_info
    @user.to_json
  end

  def user_fav_list
    fav = Bilibili::Fav.new(http_client)
    fav.list_user_fav_video(@user)
  end
end
