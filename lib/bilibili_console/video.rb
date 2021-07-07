# frozen_string_literal: true

require_relative 'http/http'

# video module
module Bilibili
  include BiliHttp
  # bilibili video interfaces
  class Video < BilibiliBase
  end
end
