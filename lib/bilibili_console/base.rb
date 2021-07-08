# frozen_string_literal: true

require_relative 'http/http'
require 'json'

# bilibili base
module Bilibili
  include BiliHttp
  # base class
  class BilibiliBase
    attr_accessor :http_client

    def initialize(http_client)
      @http_client = http_client
    end

    # get json for login_http
    def get_jsonl(url)
      @http_client.get_json(@http_client.login_http, url)
    end

    def get_jsona(url)
      @http_client.get_json(@http_client.api_http, url)
    end

    def post_form_jsonl(url, params)
      @http_client.post_form_json(@http_client.login_http, url, params)
    end

    def post_form_jsona(url, params)
      @http_client.post_form_json(@http_client.api_http, url, params)
    end

    def save_cookie
      @http_client.api_http.cookies = @http_client.login_http.cookies
      json_str = @http_client.login_http.cookies.to_json
      File.open('cookie.txt', 'w') do |file|
        file.write(json_str)
      end
    end

    def load_cookie
      return @http_client.api_http.cookies unless @http_client.api_http.cookies.nil?

      cookie_file = 'cookie.txt'
      return nil unless File.exist?(cookie_file)

      json_str = File.read(cookie_file)
      @http_client.api_http.cookies = JSON.parse(json_str)
    end
  end
end
