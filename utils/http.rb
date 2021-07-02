# frozen_string_literal: true

require 'nice_http'
require_relative 'base'
require_relative 'response_body'

# bilibili client http module
module BiliHttp
  # bilibili http client
  class HttpClient
    attr_accessor :login_http, :api_http

    def initialize
      @login_http = NiceHttp.new('http://passport.bilibili.com')
      @api_http = NiceHttp.new('http://api.bilibili.com')
    end

    def get_json(http, uri)
      response = get(http, uri)
      json_data(response)
    end

    def get(http, uri)
      response = http.get(uri.request_uri)
      response.data
    end

    def post_form_json(http, uri, params)
      request = {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        path: uri.request_uri,
        data: params
      }
      response = http.post(request)
      json_data(response.data)
    end

    def json_data(data)
      body = BiliHttp::ResponseBody.new(data.json)
      body.data
    end

    include Base
  end
end
