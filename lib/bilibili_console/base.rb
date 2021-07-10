require_relative 'http/http'
require 'json'

# bilibili base
module Bilibili
  include BiliHttp
  # base class
  class BilibiliBase
    attr_accessor :http_client

    class << self
      attr_accessor :video_qn
    end

    def initialize(http_client)
      @http_client = http_client
      BilibiliBase.video_qn = {
        '240' => 6, '360' => 16, '480' => 32,
        '720' => 64, '720P60' => 74, '1080' => 80,
        '1080+' => 112, '1080P60' => 116, '4K' => 120,
        'HDR' => 125
      }
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
      return @http_client.api_http.cookies unless @http_client.api_http.cookies.empty?

      cookie_file = 'cookie.txt'
      return nil unless File.exist?(cookie_file)

      json_str = File.read(cookie_file)
      @http_client.api_http.cookies = JSON.parse(json_str)
      @http_client.api_http.cookies
    end
  end
end
