require 'net/http'
require 'nice_http'
require_relative 'response_body'

# bilibili client http module
module BiliHttp
  class << self
    attr_accessor :headers
  end
  # bilibili http client
  class HttpClient
    attr_accessor :login_http, :api_http

    def initialize
      @login_http = NiceHttp.new('http://passport.bilibili.com')
      @api_http = NiceHttp.new('http://api.bilibili.com')
      BiliHttp.headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
        'Referer': 'https://www.bilibili.com'
      }
    end

    def get_json(http, url)
      json_data(get(http, url))
    end

    def get(http, url)
      request = {
        headers: BiliHttp.headers,
        path: URI(url).request_uri
      }
      http.get(request).data
    end

    def post_form_json(http, url, params)
      custom_headers = BiliHttp.headers.clone
      custom_headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request = {
        headers: custom_headers,
        path: URI(url).request_uri,
        data: params
      }
      json_data(http.post(request).data)
    end

    def json_data(data)
      body = BiliHttp::ResponseBody.new(data.json)
      body.data
    end
  end
end
