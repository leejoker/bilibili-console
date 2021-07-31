# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require 'json'

# bilibili base
module Bilibili
  include BiliHttp
  # base class
  class BilibiliBase
    attr_accessor :http_client, :options

    class << self
      attr_accessor :video_qn
    end

    def initialize(http_client)
      @http_client = http_client
      @options = {
        'config_path' => '~/.bc',
        'config_file' => '~/.bc/config.json',
        'cookie_file' => '~/.bc/cookie.txt',
        'download_path' => '~/.bc/download'
      }
      BilibiliBase.video_qn = {
        '240' => 6, '360' => 16, '480' => 32,
        '720' => 64, '720P60' => 74, '1080' => 80,
        '1080+' => 112, '1080P60' => 116, '4K' => 120,
        'HDR' => 125
      }
    end

    # get json for login_http
    # TODO use meta program to create these methods automaticly
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

    def post_jsonm(url, headers, req_body)
      @http_client.post_json(@http_client.manga_http, url, headers, req_body)
    end

    def save_cookie
      @http_client.api_http.cookies = @http_client.login_http.cookies
      json_str = @http_client.login_http.cookies.to_json
      File.open(@options['cookie_file'].to_s, 'w') do |file|
        file.write(json_str)
      end
    end

    def load_cookie
      return {} unless File.exist?(@options['cookie_file'].to_s)

      json_str = File.read(@options['cookie_file'].to_s)
      return {} if json_str.blank?

      cookies = JSON.parse(json_str)
      @http_client.api_http.cookies = cookies
      BiliHttp.headers['Cookie'] = create_cookie_str(cookies)
      cookies
    end

    def clean_cookie
      File.open(@options['cookie_file'].to_s, 'w') do |file|
        file.write('{}')
      end
    end

    private

    def create_cookie_str(cookies)
      cookies_to_set_str = ''
      cookies.each do |key, value|
        cookies_to_set_str += "#{key}=#{value}; "
      end
      cookies_to_set_str
    end
  end
end
