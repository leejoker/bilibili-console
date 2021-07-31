# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

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

    def to_json(*opt)
      {
        face: @face,
        level_info: @level_info,
        uid: @uid,
        money: @money,
        moral: @moral,
        uname: @uname,
        vip_type: @vip_type
      }.to_json(*opt)
    end
  end

  # login class
  class Login < BilibiliBase
    attr_accessor :url, :oauth_key

    def login_url
      data = get_jsonl('http://passport.bilibili.com/qrcode/getLoginUrl')
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

    def login_user_info
      puts check_cookie_empty
      login if check_cookie_empty
      data = get_jsona('http://api.bilibili.com/nav')
      if data.code != -101
        Bilibili::UserInfo.new(data)
      else
        puts 'Cookie已失效'
        clean_cookie
        login_user_info
      end
    end

    def login
      login_url
      show_qrcode
      print '已完成扫码？[y/n]'
      over = gets.chomp
      return nil unless over == 'y'

      post_form_jsonl('http://passport.bilibili.com/qrcode/getLoginInfo', { oauthKey: @oauth_key })
      puts 'Login Success !!!'
      save_cookie
      'success'
    end

    private

    def check_cookie_empty
      cookie = load_cookie
      cookie.nil? || cookie.empty?
    end
  end
end
