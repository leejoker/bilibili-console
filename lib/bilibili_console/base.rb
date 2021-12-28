# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'config'
require_relative 'http/http'
require 'json'
require 'logger'

# bilibili base
module Bilibili
  include BiliHttp

  # bilibili record class meta base
  class BiliBliliRecordBase
    def initialize(json)
      return if json.nil?

      hash = {}
      public_methods(false).filter { |m| m.name.index('=').nil? }.each do |method|
        next if json[method.name.to_sym].nil?

        value = method("#{method.name}=".to_sym).call(json[method.name.to_sym])
        hash.merge!({ method.name => value })
      end

      BiliBliliRecordBase.define_method('to_json') do |*opt|
        hash.to_json(*opt)
      end
    end
  end

  # base class
  class BilibiliBase
    attr_accessor :log, :client, :opt

    class << self
      attr_accessor :options, :logger, :http_client
    end

    def initialize
      @client = BilibiliBase.http_client
      create_request_methods
      BilibiliBase.options = Config.new if BilibiliBase.options.nil?
      @opt = BilibiliBase.options.options
      @log = Logger.new(File.new(@opt[:log_file], 'w+'))
    end

    def save_cookie
      @client.api_http.cookies = @client.login_http.cookies
      json_str = @client.login_http.cookies.to_json
      @log.info("cookie_json: #{json_str}")
      write_cookie(json_str)
    end

    def load_cookie
      return {} unless File.exist?(@opt[:cookie_json])

      json_str = File.read(@opt[:cookie_json])
      return {} if json_str.nil? || json_str.empty?

      JSON.parse(json_str)
    end

    def clean_cookie
      File.open(@opt[:cookie_json], 'w') do |file|
        file.write('{}')
      end
    end

    private

    def write_cookie(cookie)
      File.open(@opt[:cookie_json], 'w') do |file|
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
        @log.debug("#{new_method_name}: [url]= #{url}")
        @client.get_json(@client.instance_variable_get("@#{method_name}"), url)
      end
    end

    def define_post_form_json_method(method_name)
      new_method_name = "post_form_json#{method_name[0]}"
      BilibiliBase.define_method(new_method_name) do |url, params|
        @log.debug("#{new_method_name}: [url]= #{url}, params= #{params}")
        @client.post_form_json(@client.instance_variable_get("@#{method_name}"), url, params)
      end
    end

    def define_post_json_method(method_name)
      new_method_name = "post_json#{method_name[0]}"
      BilibiliBase.define_method(new_method_name) do |url, headers, req_body|
        @log.debug("#{new_method_name}: [url]= #{url}, headers= #{headers}, req_body= #{req_body}")
        @client.post_json(@client.instance_variable_get("@#{method_name}"), url, headers, req_body)
      end
    end

    def os
      @os ||= (
        host_os = RbConfig::CONFIG['host_os']
        case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /darwin|mac os/
          :macosx
        when /linux/
          :linux
        when /solaris|bsd/
          :unix
        else
          raise StandardError, "unknown os: #{host_os.inspect}"
        end
      )
    end
  end
end
