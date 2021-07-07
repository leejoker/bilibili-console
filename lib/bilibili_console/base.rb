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
  end
end
