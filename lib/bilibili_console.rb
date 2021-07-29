require_relative 'bilibili_console/http/http'
require_relative 'bilibili_console/login'
require_relative 'bilibili_console/fav'
require_relative 'bilibili_console/video'

# bilibili console main class
class BilibiliConsole
  HTTP_CLIENT = BiliHttp::HttpClient.new
  BILIBILI_LOGIN = Bilibili::Login.new(HTTP_CLIENT)
  FAV = Bilibili::Fav.new(HTTP_CLIENT)
  VIDEO = Bilibili::Video.new(HTTP_CLIENT)
  MANGA = Bilibili::Manga.new(HTTP_CLIENT)

  attr_accessor :user

  def self.login
    BILIBILI_LOGIN.login
  end

  def self.login_user_info
    BILIBILI_LOGIN.login_user_info
  end

  def self.user_fav_list
    user = login_user_info
    FAV.list_user_fav_video(user)
  end

  def list_fav_video(media_id, page_num = 1, page_size = 10, keyword = nil)
    FAV.list_fav_video(media_id, page_num, page_size, keyword)
  end

  def download_video(bv_id)
    VIDEO.download_video_by_bv(bv_id)
  end

  def manga_checkin
    MANGA.check_in
  end
end
