# frozen_string_literal: true

require 'http-cookie'

module BiliHttp
  # response body
  class ResponseHeader
    attr_accessor :content_type, :transfer_encoding, :connection, :server, :set_cookies, :expires, :cache_control

    def initialize(headers = [])
      @content_type = headers['content_type']
      @transfer_encoding = headers['transfer_encoding']
      @connection = headers['connection']
      @server = headers['server']
      @set_cookies = headers['set_cookies']
      @expires = headers['expires']
      @cache_control = headers['cache_control']
    end

    def save_cookie
        cookie_file = '../cookie'
        jar = HTTP::CookieJar.new
        jar.load(cookie_file) if File.exist?(cookie_file)
        @set_cookies.each { |value|
            jar.parse(value, '/')
        }
        header["Cookie"] = HTTP::Cookie.cookie_value(jar.cookies(uri))
        jar.save(filename)
    end

    def to_s
      <<DOC
        Content-Type: @content_type
        Transfer-Encoding: @transfer_encoding
        Connection: @connection
        Server: @server
        Set-Cookie: @set_cookies[0]
        Set-Cookie: @set_cookies[1]
        Set-Cookie: @set_cookies[2]
        Set-Cookie: @set_cookies[3]
        Set-Cookie: @set_cookies[4]
        Expires: @expires
        Cache-Control: @cache_control
      DOC
    end
  end
end
