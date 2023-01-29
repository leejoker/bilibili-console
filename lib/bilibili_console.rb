# frozen_string_literal: true

require_relative 'bilibili_console/base/base'
require_relative 'bilibili_console/base/record_base'
require_relative 'bilibili_console/fav'
require_relative 'bilibili_console/http/http'
require_relative 'bilibili_console/util/doctor_utils'
require_relative 'bilibili_console/login'
require_relative 'bilibili_console/manga'
require_relative 'bilibili_console/search'
require_relative 'bilibili_console/video'

module Bilibili
  # bilibili console main class
  class BilibiliConsole
    attr_accessor :user, :login, :fav, :video

    def do_login
      @login = Bilibili::Login.new
      @login.login
    end

    def login_user_info
      @login = Bilibili::Login.new if @login.nil?
      @login.login_user_info
    end

    def user_fav_list
      @fav = Bilibili::Fav.new if @fav.nil?
      @user = login_user_info if @user.nil?
      @fav.list_user_fav_video(@user)
    end

    def list_fav_video(options)
      @fav = Bilibili::Fav.new if @fav.nil?
      @fav.list_fav_video(options)
    end

    def download_video(bv_id, options)
      @video = Bilibili::Video.new if @video.nil?
      urls = @video.download_video_by_bv(bv_id, options)
      @video.combine_downloaded_videos(bv_id, urls)
    end

    def manga_checkin
      manga = Bilibili::Manga.new
      manga.check_in
    end

    def manga_checkin_info
      manga = Bilibili::Manga.new
      manga.check_in_info
    end

    def search_keyword(options)
      search = Bilibili::Search.new
      search.search(options)
    end

    def doctor
      base = BilibiliBase.new
      Bilibili::Doctor.check_wget unless base.opt[:enable_aria2]
      Bilibili::Doctor.check_aria2 if base.opt[:enable_aria2]
    end
  end
end
