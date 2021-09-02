require_relative 'bilibili_console/http/http'
require_relative 'bilibili_console/login'
require_relative 'bilibili_console/fav'
require_relative 'bilibili_console/video'
require_relative 'bilibili_console/manga'

# bilibili console main class
class BilibiliConsole
  attr_accessor :http_client, :bilibili_login, :user, :fav, :video, :manga

  def initialize
    @http_client = BiliHttp::HttpClient.new
    @bilibili_login = Bilibili::Login.new(@http_client)
    @fav = Bilibili::Fav.new(@http_client)
    @video = Bilibili::Video.new(@http_client)
    @manga = Bilibili::Manga.new(@http_client)
  end

  def login
    set_login_http
    @bilibili_login.login
  end

  def login_user_info
    set_login_http
    set_api_http
    @user = @bilibili_login.login_user_info
    @user
  end

  def user_fav_list
    set_api_http
    @fav.list_user_fav_video(@user)
  end

  def list_fav_video(media_id, page_num = 1, page_size = 10, keyword = nil)
    set_api_http
    @fav.list_fav_video(media_id, page_num, page_size, keyword)
  end

  def download_video(bv_id)
    set_api_http
    @video.download_video_by_bv(bv_id)
  end

  def manga_checkin
    set_manga_http
    @manga.check_in
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
