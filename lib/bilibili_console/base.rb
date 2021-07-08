# frozen_string_literal: true

require_relative 'http/http'

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

    def share_cookie
      @http_client.api_http.cookies = @http_client.login_http.cookies
    end
  end
end
