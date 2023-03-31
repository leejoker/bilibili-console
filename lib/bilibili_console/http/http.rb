# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'net/http'
require 'json'
require 'socksify/http'
require_relative 'response_body'

# bilibili client http module
module BiliHttp
  class << self
    attr_accessor :headers, :proxy
  end

  class BiliHttpClient
    attr_accessor :http, :cookies, :ssl, :port

    def initialize(port = nil, ssl = false, proxy = {})
      @http = Net::HTTP
      @cookies = {}
      @ssl = ssl
      @port = port unless port.nil?
      return if proxy.nil? || proxy.empty?

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
      req = Net::HTTP::Get.new(path, request_headers(request))
      do_request(uri.host, @port, ssl, req)
    end

    def get_stream(request)
      uri = request[:path]
      path = uri.path + (uri.query ? ('?' + uri.query) : '')
      req = Net::HTTP::Get.new(path, request_headers(request))
      save_path = request[:save_data]
      @http.start(uri.host, @port, use_ssl: ssl, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        response = http.request(req)
        code = response.code.to_i
        if code == 301 || code == 302
          request[:path] = URI(response['location'])
          get_stream(request)
        else
          File.open(save_path, 'wb+') do |file|
            file.write(response.body)
          end
        end
      end
    end

    def post_json(request)
      uri = request[:path]
      data = request[:data]
      req = Net::HTTP::Post.new(uri.path, request_headers(request))
      req.body = data unless data.nil?
      do_request(uri.host, @port, ssl, req)
    end

    def post_form(request)
      uri = request[:path]
      form_data = request[:data]
      req = Net::HTTP::Post.new(uri.path, request_headers(request))
      req.set_form_data(form_data)
      do_request(uri.host, @port, ssl, req)
    end

    private

    def do_request(host, port, ssl, request)
      @http.start(host, port, use_ssl: ssl, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        response = http.request(request)
        $log.debug(<<~REQUEST
          host:       #{host}
          port:       #{port}
          ssl:        #{ssl}
          cookie:     #{request['Cookie']}
          path:       #{request.path}
        REQUEST
        )
        response_headers(response)
        $log.debug("response body: #{response.body.to_s}")
        response.body.to_s
      end
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
      http.get(request)
    end

    # post method with form data
    def post_form_json(http, url, headers, params)
      headers = BiliHttp.headers.clone if headers.nil? || headers.empty?
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request = {
        headers: headers,
        path: URI(url),
        data: params
      }
      json_data(http.post_form(request))
    end

    # post method with json body
    def post_json(http, url, headers, req_body)
      headers = BiliHttp.headers.clone if headers.nil? || headers.empty?
      headers['Content-Type'] = 'application/json' unless req_body.nil? || req_body.empty?
      request = {
        headers: headers,
        path: URI(url)
      }
      request.merge!({ data: req_body.to_json }) unless req_body.nil? || req_body.empty?
      json_data(http.post_json(request))
    end

    def json_data(data)
      return if data.nil? || data.empty?

      body = BiliHttp::ResponseBody.new(JSON.parse(data, symbolize_names: true))
      if body.data.nil?
        body
      else
        body.data
      end
    end
  end
end
