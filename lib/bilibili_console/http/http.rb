require 'net/http'
require 'nice_http'
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

    def get_json(http, url)
      response = get(http, url)
      json_data(response)
    end

    def get(http, url)
      uri = URI(url)
      response = http.get(uri.request_uri)
      response.data
    end

    def post_form_json(http, url, params)
      uri = URI(url)
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
  end
end
