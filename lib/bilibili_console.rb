# frozen_string_literal: true

require_relative 'bilibili_console/http/http'
require_relative 'bilibili_console/login'
require_relative 'bilibili_console/fav'

# bilibili console main class
class BilibiliConsole
  attr_accessor :http_client, :bilibili_login, :user, :fav

  def initialize
    @http_client = BiliHttp::HttpClient.new
    @bilibili_login = Bilibili::Login.new(@http_client)
    @fav = Bilibili::Fav.new(http_client)
  end

  def login
    @bilibili_login.login
  end

  def login_user_info
    @user = @bilibili_login.login_user_info
  end

  def user_fav_list
    @fav.list_user_fav_video(@user)
  end

  def list_fav_video(media_id, page_num = 1, page_size = 10, keyword = nil)
    @fav.list_fav_video(media_id, page_num, page_size, keyword)
  end
end
