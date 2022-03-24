# frozen_string_literal: true

require_relative 'bilibili_console/http/http'
require_relative 'bilibili_console/login'
require_relative 'bilibili_console/fav'
require_relative 'bilibili_console/video'
require_relative 'bilibili_console/manga'
require_relative 'bilibili_console/search'

# bilibili console main class
class BilibiliConsole
  attr_accessor :http_client, :bilibili_login, :user, :fav, :video, :manga, :search

  def initialize
    @http_client = BiliHttp::HttpClient.new
    Bilibili::BilibiliBase.http_client = @http_client
    @bilibili_login = Bilibili::Login.new
    @fav = Bilibili::Fav.new
    @video = Bilibili::Video.new
    @manga = Bilibili::Manga.new
    @search = Bilibili::Search.new
  end

  def login
    set_login_http
    set_api_http
    @bilibili_login.login
  end

  def login_user_info
    set_login_http
    set_api_http
    @bilibili_login.login_user_info
  end

  def user_fav_list
    @user = login_user_info if @user.nil?
    set_api_http
    @fav.list_user_fav_video(@user)
  end

  def list_fav_video(options)
    set_api_http
    @fav.list_fav_video(options)
  end

  def download_video(bv_id, options)
    set_api_http
    urls = @video.download_video_by_bv(bv_id, options)
    @video.combine_downloaded_videos(bv_id, urls)
  end

  def manga_checkin
    set_manga_http
    @manga.check_in
  end

  def search_keyword(options)
    set_api_http
    @search.search(options)
  end

  private

  def set_login_http
    @http_client.login_http = NiceHttp.new('https://passport.bilibili.com')
    @http_client.login_http.cookies = @bilibili_login.load_cookie
  end

  def set_api_http
    @http_client.api_http = NiceHttp.new('https://api.bilibili.com')
    @http_client.api_http.cookies = @bilibili_login.load_cookie
  end

  def set_manga_http
    @http_client.manga_http = NiceHttp.new('https://manga.bilibili.com')
    @http_client.manga_http.cookies = @bilibili_login.load_cookie
  end
end
