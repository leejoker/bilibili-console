# frozen_string_literal: true

require_relative 'http/http'
require_relative 'base'
require 'rqrcode'
require 'json'

# login module
module Bilibili
  include BiliHttp
  # bilibili user info
  class UserInfo
    attr_accessor :face, :level_info, :uid, :money, :moral, :uname, :vip_type

    def initialize(json)
      return if json.nil?

      @face = json[:face]
      @level_info = json[:level_info]
      @uid = json[:mid]
      @money = json[:money]
      @moral = json[:moral]
      @uname = json[:moral]
      @vip_type = json[:vipType]
    end
  end

  # login class
  class Login < BilibiliBase
    attr_accessor :url, :oauth_key

    def login_url
      url = 'http://passport.bilibili.com/qrcode/getLoginUrl'
      data = get_jsonl(url)
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
      post_form_jsonl(url, { oauthKey: @oauth_key })
    end

    def login_user_info
      url = 'http://api.bilibili.com/nav'
      data = get_jsona(url)
      Bilibili::UserInfo.new(data)
    end

    def login
      login_url
      show_qrcode
      print '已完成扫码？[y/n]'
      over = gets.chomp
      return nil unless over == 'y'

      login_info
      puts 'Login Success !!!'
      save_cookie
      'success'
    end
  end
end
