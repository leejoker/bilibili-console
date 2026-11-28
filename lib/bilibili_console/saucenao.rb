# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'json'
require 'net/http'
require_relative 'http/http'

# saucenao reverse image search
module Bilibili
  # saucenao client (json api, requires an api key)
  class Saucenao
    ENDPOINT = URI('https://saucenao.com/search.php')
    DEFAULT_DB = 999
    API_KEY_ENV = 'SAUCENAO_API_KEY'
    MISSING_KEY_MESSAGE = '未配置 saucenao api key：请在 ~/.bc/bilic.conf 设置 "saucenao_api_key"，或设置环境变量 SAUCENAO_API_KEY'

    # one parsed saucenao result
    Result = Struct.new(:similarity, :index_name, :title, :urls, keyword_init: true)

    def initialize(api_key = nil, proxy = nil)
      @api_key = (api_key || ENV[API_KEY_ENV]).to_s.strip
      @proxy = proxy || {}
    end

    def search(target, db: DEFAULT_DB)
      raise MISSING_KEY_MESSAGE if @api_key.empty?

      payload = if File.file?(target.to_s)
                  upload(target.to_s, db)
                else
                  lookup(target.to_s, db)
                end
      parse(payload)
    end

    private

    def lookup(url, db)
      raise '图片地址为空' if url.empty?

      req = Net::HTTP::Post.new(ENDPOINT)
      req.set_form_data('url' => url, 'output_type' => '2', 'db' => db.to_s, 'api_key' => @api_key)
      perform(req)
    end

    def upload(path, db)
      boundary = "----saucenao#{rand(10**12)}"
      body = +''
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"api_key\"\r\n\r\n#{@api_key}\r\n"
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"output_type\"\r\n\r\n2\r\n"
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"db\"\r\n\r\n#{db}\r\n"
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(path)}\"\r\n"
      body << "Content-Type: application/octet-stream\r\n\r\n"
      body << File.binread(path)
      body << "\r\n--#{boundary}--\r\n"

      req = Net::HTTP::Post.new(ENDPOINT)
      req['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      req.body = body
      perform(req)
    end

    def perform(req)
      req['User-Agent'] = BiliHttp.headers ? BiliHttp.headers[:"User-Agent"].to_s : 'Mozilla/5.0'
      res = http_class.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true) { |http| http.request(req) }
      body = res.body.to_s
      payload = begin
        JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        raise "saucenao 返回了非 JSON 内容（HTTP #{res.code}）"
      end

      header = payload[:header] || {}
      raise "saucenao 错误：#{header[:message] || "status #{header[:status]}"}" if header[:status].to_i.negative?

      payload
    end

    def http_class
      return Net::HTTP if @proxy.nil? || @proxy.empty? || @proxy[:url].to_s.empty?

      if @proxy[:type].to_s == 'socks'
        Net::HTTP.SOCKSProxy(@proxy[:url], @proxy[:port].to_i)
      else
        Net::HTTP::Proxy(@proxy[:url], @proxy[:port].to_i)
      end
    end

    def parse(payload)
      (payload[:results] || []).map do |item|
        header = item[:header] || {}
        data = item[:data] || {}
        Result.new(
          similarity: header[:similarity].to_s,
          index_name: header[:index_name].to_s,
          title: (data[:title] || data[:eng_name] || data[:jp_name]).to_s,
          urls: Array(data[:ext_urls]).map(&:to_s)
        )
      end
    end
  end
end
