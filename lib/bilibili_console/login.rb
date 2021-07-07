# frozen_string_literal: true

require_relative 'user_info'
require_relative 'http/http'
require_relative 'base'
require 'rqrcode'

# login module
module Bilibili
  include BiliHttp
  # login class
  class Login < BilibiliBase
    attr_accessor :url, :oauth_key

    def login_url
      url = 'http://passport.bilibili.com/qrcode/getLoginUrl'
      data = @http_client.get_json(@http_client.login_http, url)
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
      @http_client.post_form_json(@http_client.login_http, url, { oauthKey: @oauth_key })
    end

    def login_user_info
      url = 'http://api.bilibili.com/nav'
      data = @http_client.get_json(@http_client.api_http, url)
      user = Bilibili::UserInfo.new
      user.init_attrs(data)
      user
    end

    def login
      login_url
      show_qrcode
      print '已完成扫码？[y/n]'
      over = gets.chomp
      return nil unless over == 'y'

      login_info
      puts 'Login Success !!!'
      @http_client.api_http.cookies = @http_client.login_http.cookies
      'success'
    end
  end
end