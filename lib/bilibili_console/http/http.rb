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
  # bilibili 风控拦截时返回 HTTP 200 + HTML 页面，或 JSON code=-412/-352
  BLOCK_PAGE_PREFIXES = ['<!doctype', '<html'].freeze
  BLOCK_CODES = [-412, -352].freeze
  BLOCK_RETRY_LIMIT = 2
  BLOCK_RETRY_INTERVAL = 3

  # raised when bilibili keeps answering with its risk-control page
  class RequestBlockedError < StandardError; end

  # raised when an API payload carries a non-zero business code
  class ApiError < StandardError; end

  class << self
    attr_accessor :headers, :proxy
  end

  class BiliHttpClient
    attr_accessor :http, :cookies, :ssl, :port

    # 支持的 proxy_type：https 与 http 等价（Net::HTTP 只有明文 CONNECT 隧道，没有 TLS 到代理的通道）
    PROXY_TYPES_HTTP = %w[http https].freeze
    PROXY_TYPES_SOCKS = %w[socks socks5 socks5h].freeze

    def initialize(port = nil, ssl = false, proxy = {})
      @http = Net::HTTP
      @connections = {}
      @cookies = {}
      @ssl = ssl
      @port = port unless port.nil?
      return if proxy.nil? || proxy.empty?

      proxy_type = proxy[:type].to_s.downcase
      proxy_type = 'http' if proxy_type.empty?
      if PROXY_TYPES_HTTP.include?(proxy_type)
        $log&.warn("proxy_type=#{proxy_type} 按普通 HTTP 代理（CONNECT 隧道）处理") if proxy_type == 'https'
        BiliHttp.proxy = Net::HTTP::Proxy(proxy[:url], proxy[:port])
      elsif PROXY_TYPES_SOCKS.include?(proxy_type)
        BiliHttp.proxy = Net::HTTP.SOCKSProxy(proxy[:url], proxy[:port])
      else
        raise "unknown proxy type: #{proxy[:type]}（支持 #{(PROXY_TYPES_HTTP + PROXY_TYPES_SOCKS).join('/')}）"
      end
      @http = BiliHttp.proxy
    end

    def get(request)
      uri = request[:path]
      path = uri.path + (uri.query ? ('?' + uri.query) : '')
      headers = request_headers(request)
      req = Net::HTTP::Get.new(path, headers)
      $log.debug(<<~GET
        url:      #{path}
        headers:  #{headers.to_json}
      GET
      )
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

    # 走代理时连接被重置/握手失败是常态，重试几次再放弃
    NETWORK_ERRORS = [
      OpenSSL::SSL::SSLError, EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED,
      Errno::EPIPE, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout
    ].freeze
    # 代理隧道做 TLS 握手失败一次就要 5s，次数给足，间隔线性拉长
    NETWORK_RETRY_LIMIT = 4
    NETWORK_RETRY_INTERVAL = 1

    def do_request(host, port, ssl, request)
      blocked_attempt = 0
      loop do
        body = perform_with_network_retry(host, port, ssl, request)
        blocked = blocked_body?(body)
        return body unless blocked

        blocked_attempt += 1
        if blocked_attempt > BiliHttp::BLOCK_RETRY_LIMIT
          raise BiliHttp::RequestBlockedError, blocked_message(blocked_attempt, blocked)
        end

        $log&.warn("bilibili 风控拦截（#{blocked}），第 #{blocked_attempt} 次重试：#{request.path}")
        sleep BiliHttp::BLOCK_RETRY_INTERVAL
      end
    end

    def perform_with_network_retry(host, port, ssl, request)
      attempt = 0
      begin
        attempt += 1
        perform_request(host, port, ssl, request)
      rescue *NETWORK_ERRORS => e
        close_connections
        raise if attempt > NETWORK_RETRY_LIMIT

        $log&.warn("网络异常（#{e.class}: #{e.message}），第 #{attempt} 次重试：#{request.path}")
        sleep(NETWORK_RETRY_INTERVAL * attempt)
        retry
      end
    end

    # returns a human-readable marker when the response is a risk-control
    # answer (HTML challenge page or JSON with code -412/-352), else nil
    def blocked_body?(body)
      text = body.to_s
      head = text.lstrip[0, 16].to_s.downcase
      return 'HTML 风控页' if BiliHttp::BLOCK_PAGE_PREFIXES.any? { |prefix| head.start_with?(prefix) }

      parsed = begin
        JSON.parse(text, symbolize_names: true)
      rescue JSON::ParserError
        return nil
      end
      return nil unless parsed.is_a?(Hash)

      code = parsed[:code]
      BiliHttp::BLOCK_CODES.include?(code) ? "code=#{code} #{parsed[:message]}" : nil
    end

    def blocked_message(attempt, blocked)
      "bilibili 风控拦截（#{blocked}，已尝试 #{attempt} 次），请检查代理配置或稍后重试"
    end

    def perform_request(host, port, ssl, request)
      http = connection(host, port, ssl)
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

    # 同一 host 复用一条连接：每条请求都重新做 TLS 握手的话，代理抖动时几乎必然失败
    def connection(host, port, ssl)
      key = [host, port, ssl]
      cached = @connections[key]
      return cached if cached&.started?

      http = @http.new(host, port)
      http.use_ssl = ssl
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ssl
      http.open_timeout = 10
      http.read_timeout = 30
      http.keep_alive_timeout = 30
      http.start
      @connections[key] = http
    end

    def close_connections
      @connections.each_value do |conn|
        conn.finish if conn.started?
      rescue IOError, SystemCallError
        nil
      end
      @connections = {}
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
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
        'Origin': 'https://www.bilibili.com',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'sec-ch-ua': '"Chromium";v="131", "Google Chrome";v="131", "Not_A Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-site'
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
        raise BiliHttp::ApiError, "bilibili 接口错误：code=#{body.code} message=#{body.message}" unless body.code.to_i.zero?

        return body
      end

      body.status && body.data.empty? ? body : body.data
    end
  end
end