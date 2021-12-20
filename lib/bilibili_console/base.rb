# frozen_string_literal: true

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

  # bilibili record class meta base
  class BiliBliliRecordBase
    def initialize(json)
      return if json.nil?
      
      hash = {}
      public_methods(false).filter { |m| m.name.index('=').nil? }.each do |method|
        value = method("#{method.name}=".to_sym).call(json[method.name]) unless json[method.name].nil?
        hash.merge!({ method.name => value }) unless json[method.name].nil?
      end

      BiliBliliRecordBase.define_method('to_json') do |*opt|
        hash.to_json(*opt)
      end
    end
  end

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
      return {} unless File.exist?(cookie_path)

      json_str = File.read(cookie_path)
      return {} if json_str.nil? || json_str.empty?

      JSON.parse(json_str)
    end

    def clean_cookie
      File.open(cookie_path, 'w') do |file|
        file.write('{}')
      end
    end

    private

    def check_config_path
      FileUtils.mkdir_p(config_path) unless Dir.exist?(config_path)
    end

    def write_cookie(cookie)
      File.open(cookie_path, 'w') do |file|
        file.write(cookie)
      end
    end

    def create_request_methods
      methods = %w[login_http api_http manga_http]
      methods.each do |method|
        define_get_json_method(method)
        define_post_form_json_method(method)
        define_post_json_method(method)
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

    def config_path
      File.expand_path(@options['config_path'].to_s, __dir__)
    end

    def cookie_path
      File.expand_path(@options['cookie_file'].to_s, __FILE__)
    end
  end
end
