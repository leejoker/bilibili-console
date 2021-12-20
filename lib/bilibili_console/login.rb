# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'base'
require_relative 'api'
require 'rqrcode'
require 'json'

# login module
module Bilibili
  include BiliHttp
  # bilibili user info
  class UserInfo < BiliBliliRecordBase
    attr_accessor :face, :level_info, :mid, :money, :moral, :uname
  end

  # login class
  class Login < BilibiliBase
    attr_accessor :url, :oauth_key

    def login_url
      data = get_jsonl(Api::Login::QRCODE)
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
      set_http_cookie
      data = get_jsona(Api::Login::USERINFO)
      if data.code != '-101'
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
      over = $stdin.gets.chomp
      return nil unless over == 'y'

      post_form_jsonl(Api::Login::INFO, { oauthKey: @oauth_key })
      puts 'Login Success !!!'
      save_cookie
      'success'
    end

    private

    def set_http_cookie
      cookies = @http_client.login_http.cookies
      if cookies.nil? || cookies.empty?
        login
        @http_client.api_http.cookies = @http_client.login_http.cookies
      else
        @http_client.api_http.cookies = cookies
      end
    end
  end
end
