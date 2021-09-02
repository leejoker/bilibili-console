# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require 'fileutils'
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
      create_request_methods
      @options = {
        'config_path' => '~/.bc', 'config_file' => '~/.bc/config.json',
        'cookie_file' => '~/.bc/cookie.txt', 'download_path' => '~/.bc/download'
      }
      BilibiliBase.video_qn = {
        '240' => 6, '360' => 16, '480' => 32, '720' => 64, '720P60' => 74, '1080' => 80,
        '1080+' => 112, '1080P60' => 116, '4K' => 120, 'HDR' => 125
      }
    end

    def save_cookie
      check_config_path

      @http_client.api_http.cookies = @http_client.login_http.cookies
      json_str = @http_client.login_http.cookies.to_json
      write_cookie(json_str)
    end

    def load_cookie
      f_path = File.expand_path(@options['cookie_file'].to_s, __FILE__)
      return {} unless File.exist?(f_path)

      json_str = File.read(f_path)
      return {} if json_str.nil? || json_str.empty?

      JSON.parse(json_str)
    end

    def clean_cookie
      File.open(f_path, 'w') do |file|
        file.write('{}')
      end
    end

    private

    def check_config_path
      config_path = File.expand_path(@options['config_path'].to_s, __dir__)
      FileUtils.mkdir_p(config_path) unless Dir.exist?(config_path)
    end

    def write_cookie(cookie)
      f_path = File.expand_path(@options['cookie_file'].to_s, __FILE__)
      File.open(f_path, 'w') do |file|
        file.write(cookie)
      end
    end

    def create_request_methods
      methods = http_client_instance_methods
      methods&.each do |method|
        define_get_json_method(method)
        define_post_form_json_method(method)
        define_post_json_method(method)
      end
    end

    def http_client_instance_methods
      BiliHttp::HttpClient.instance_methods(false)&.select do |method|
        method.to_s.index('=').nil?
      end
    end

    def define_get_json_method(method_name)
      new_method_name = "get_json#{method_name[0]}"
      BilibiliBase.define_method(new_method_name) do |url|
        @http_client.get_json(@http_client.instance_variable_get("@#{method_name}"), url)
      end
    end

    def define_post_form_json_method(method_name)
      new_method_name = "post_form_json#{method_name[0]}"
      BilibiliBase.define_method(new_method_name) do |url, params|
        @http_client.post_form_json(@http_client.instance_variable_get("@#{method_name}"), url, params)
      end
    end

    def define_post_json_method(method_name)
      new_method_name = "post_json#{method_name[0]}"
      BilibiliBase.define_method(new_method_name) do |url, headers, req_body|
        @http_client.post_json(@http_client.instance_variable_get("@#{method_name}"), url, headers, req_body)
      end
    end
  end
end
