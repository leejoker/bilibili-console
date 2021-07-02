# frozen_string_literal: true

require_relative 'user_info'
require_relative '../utils/http'
require 'rqrcode'

# login module
module Bilibili
  include BiliHttp
  # login class
  class Login
    attr_accessor :url, :oauth_key

    def login_url
      url = 'http://passport.bilibili.com/qrcode/getLoginUrl'
      data = BiliHttp.get_json(url)
      @url = data[:url]
      @oauth_key = data[:oauthKey]
    end

    def show_qrcode
      qr = RQRCode::QRCode.new(@url)
      pic = qr.as_ansi(
        light: "\033[47m", dark: "\033[40m",
        fill_character: '  ',
        quiet_zone_size: 1
      )
      puts pic
    end

    def login_info
      url = 'http://passport.bilibili.com/qrcode/getLoginInfo'
      BiliHttp.post_form_json(url, { oauthKey: @oauth_key })
    end

    def login_user_info
      url = 'http://api.bilibili.com/nav'
      data = BiliHttp.get_json(url)
      user = Bilibili::UserInfo.new
      user.init_attrs(data)
    end

    def login
      login_url
      show_qrcode
      print '已完成扫码？[y/n]'
      over = gets.chomp
      login_info unless over != 'y'
      puts 'Login Success !!!'
    end
  end
end
