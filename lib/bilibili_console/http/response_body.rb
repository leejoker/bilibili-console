# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http'

# response body
module BiliHttp
  # response body
  class ResponseBody
    attr_accessor :code, :message, :ts, :data, :status

    def initialize(json)
      @code = json[:code]
      @message = json[:message]
      @ts = json[:ts]
      @status = json[:status]
      @data = json[:data]
    end

    def to_s
      "code: #{@code}, message: #{@message}, ts: #{@ts}, data: #{@data}, status: #{@status}"
    end
  end
end
