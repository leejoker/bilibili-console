# frozen_string_literal: true

require_relative 'http'
require 'json'

# response body
module BiliHttp
  # response body
  class ResponseBody
    attr_accessor :code, :message, :ts, :data, :status

    def initialize(str = '{}')
      json = JSON.parse(str)
      @code = json['code']
      @message = json['message']
      @ts = json['ts']
      @status = json['status']
      @data = json['data']
    end
  end
end
