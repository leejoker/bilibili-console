# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
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
    attr_accessor :url, :qrcode_key

    def initialize
      super
      @client.login_http = BiliHttp::BiliHttpClient.new(@opt[:port], @opt[:ssl], BilibiliBase.proxy)
      @client.login_http.cookies = @cookies
    end

    def login_url
      data = get_jsonl(Api::Login::QRCODE)
      return if data.nil? || data[:url].nil?

      @url = data[:url]
      @qrcode_key = data[:qrcode_key]
    end

    def show_qrcode
      return if @url.nil?

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
      if data[:isLogin]
        Bilibili::UserInfo.new(data)
      else
        puts 'Cookie已失效'
        clean_cookie
        login
        login_user_info
      end
    end

    def login
      login_url
      show_qrcode
      login_check
      puts 'Login Success !!!'
      save_cookie
      'success'
    end

    private

    def login_check
      data = get_jsonl("#{Api::Login::INFO}?qrcode_key=#{@qrcode_key}")
      $log.debug("login response data: #{data}")
      if data[:code] == 86_101 || data[:code] == 86_090
        sleep 2
        login_check
      elsif data[:code] == 86_038
        sleep 10
        login
      else
        true
      end
    end

    def set_http_cookie
      cookies = @client.login_http.cookies
      if cookies.nil? || cookies.empty?
        login
        @client.api_http.cookies = @client.login_http.cookies
      else
        @client.api_http.cookies = cookies
      end
    end
  end
end
