# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'net/http'
require 'json'
require 'socksify'
require_relative 'response_body'

# bilibili client http module
module BiliHttp
  class << self
    attr_accessor :headers, :proxy
  end

  class BiliHttpClient
    attr_accessor :http, :cookies, :ssl

    def initialize(address, port = nil, ssl = true, proxy = {})
      @http = Net::HTTP.new(address, port)
      @cookies = {}
      @ssl = ssl
      return if proxy.empty?

      case proxy[:type]
      when 'http'
        BiliHttp.proxy = Net::HTTP::Proxy(proxy[:url], proxy[:port])
      when 'socks'
        BiliHttp.proxy = Net::HTTP.SOCKSProxy(proxy[:url], proxy[:port])
      else
        raise 'unknown proxy type'
      end
      @http = BiliHttp.proxy
    end

    def get(request)
      uri = request[:path]
      path = uri.path + (uri.query ? ('?' + uri.query) : '')
      @http.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Get.new(path, request_headers(request))
        response = http.request(req)
        response_headers(response)
        response.body.to_s
      end
    end

    def post_json(request)
      uri = request[:path]
      data = request[:data]
      @http.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Post.new(uri.path, request_headers(request))
        req.body = data unless data.nil?
        response = http.request(req)
        response_headers(response)
        response.body.to_s
      end
    end

    def post_form(request)
      uri = request[:path]
      form_data = request[:data]
      @http.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Post.new(uri.path, request_headers(request))
        req.set_form_data(form_data)
        response = http.request(req)
        response_headers(response)
        response.body.to_s
      end
    end

    private

    def handle_http(http)
      return unless @ssl

      http.use_ssl = ssl
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    def makeup_cookie(cookies)
      return if cookies.empty?

      array = []
      cookies.each do |k, v|
        array.push("#{k}=#{v}")
      end
      array.join(';')
    end

    def request_headers(request)
      headers = request[:headers]
      headers['Cookie'] = makeup_cookie(@cookies) unless @cookies.empty?
      headers
    end

    def response_headers(response)
      cookie_hash = {}
      set_cookies = response.get_fields('Set-Cookie')
      return if set_cookies.nil?

      set_cookies.each do |value|
        entry = value.split('=')
        cookie_hash[entry[0]] = entry[1]
      end
      @cookies = cookie_hash
    end
  end

  # bilibili http client
  class HttpClient
    attr_accessor :login_http, :api_http, :manga_http

    def initialize
      BiliHttp.headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
        'Referer': 'https://www.bilibili.com'
      }
    end

    # get method
    def get_json(http, url)
      json_data(get(http, url))
    end

    def get(http, url)
      request = {
        headers: BiliHttp.headers,
        path: URI(url)
      }
      http.get(request).data
    end

    # post method with form data
    def post_form_json(http, url, params)
      custom_headers = BiliHttp.headers.clone
      custom_headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request = {
        headers: custom_headers,
        path: URI(url),
        data: params
      }
      json_data(http.post_form(request).data)
    end

    # post method with json body
    def post_json(http, url, headers, req_body)
      headers = BiliHttp.headers.clone if headers.nil? || headers.empty?
      headers['Content-Type'] = 'application/json' unless req_body.nil? || req_body.empty?
      request = {
        headers: headers,
        path: URI(url)
      }
      request.merge!({ data: req_body }) unless req_body.nil? || req_body.empty?
      json_data(http.post_json(request).data)
    end

    def json_data(data)
      body = BiliHttp::ResponseBody.new(JSON.parse(data))
      if body.data.nil?
        body
      else
        body.data
      end
    end
  end
end
