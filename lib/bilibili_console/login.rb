# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'api'
require 'rqrcode'
require 'json'
require 'fileutils'
require 'tmpdir'

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
      png = qr.as_png(
        bit_depth: 1,
        border_modules: 4,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: 'black',
        file: nil,
        fill: 'white',
        module_px_size: 6,
        resize_exactly_to: false,
        resize_gte_to: false,
        size: 240
      )
      qr_path = qrcode_path
      IO.binwrite(qr_path, png.to_s)
      puts "二维码已保存到 #{qr_path}，请使用哔哩哔哩 App 扫描"
      open_qrcode(qr_path)
    end

    def login_user_info
      set_http_cookie
      data = get_jsona(Api::Login::NAV)
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
      return nil if @url.nil?

      show_qrcode
      return nil unless login_check

      puts 'Login Success !!!'
      save_cookie
      'success'
    end

    private

    # 二维码固定写到配置的 tmp_dir，Windows 上不存在 /tmp，且该目录在 check_paths 里已确保存在
    def qrcode_path
      dir = @opt[:tmp_dir].to_s
      dir = Dir.tmpdir if dir.empty?
      FileUtils.mkdir_p(dir)
      File.join(dir, 'bilibili-qrcode.png')
    end

    # 尽力唤起图片查看器，打不开也不影响扫码登录（路径已经打印出来了）
    def open_qrcode(path)
      if Gem.win_platform?
        spawn('cmd', '/c', 'start', '', path, out: File::NULL, err: File::NULL)
      else
        %w[fim xdg-open open].each do |viewer|
          spawn(viewer, path, out: File::NULL, err: File::NULL)
          break
        rescue SystemCallError
          next
        end
      end
    rescue SystemCallError, NotImplementedError
      nil
    end

    QR_STATUS = {
      86101 => :waiting,
      86090 => :scanned,
      86038 => :expired
    }.freeze

    def login_check
      deadline = Time.now + 180
      while Time.now < deadline
        data = get_jsonl(Api::Login::INFO + "?qrcode_key=#{@qrcode_key}")
        $log.debug("login response data: #{data}")
        code = data.is_a?(Hash) ? data[:code] : data
        return false if code.nil?

        case QR_STATUS[code]
        when :waiting, :scanned
          sleep 2
        when :expired
          break
        else
          return true if code.to_i.zero?

          $log.warn("login poll unexpected: #{data}")
          return false
        end
      end
      puts '二维码已过期，请重新执行 bilic login'
      false
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
