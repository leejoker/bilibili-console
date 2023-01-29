# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'api'

# video module
module Bilibili
  include BiliHttp

  # bilibili video interfaces
  class Manga < BilibiliBase
    MANGA_HEADER = {
      'User-Agent': 'Mozilla/5.0 BiliDroid/6.4.0 (bbcallen@gmail.com) os/android model/M1903F11I mobi_app/android build/6040500 channel/bili innerVer/6040500 osVer/9.0.0 network/2'
    }.freeze

    def initialize
      super
      @client.manga_http = BiliHttp::BiliHttpClient.new(Bilibili::Api::MANGA_HOST, 443, true, BilibiliBase.proxy)
      @client.manga_http.cookies = @cookies
    end

    def check_in
      post_form_jsonm(Api::Manga::CHECK_IN, Bilibili::Manga::MANGA_HEADER.dup, { platform: 'android' })
    end

    def check_in_info
      post_jsonm(Api::Manga::CHECK_IN_INFO, Bilibili::Manga::MANGA_HEADER.dup, nil)
    end
  end
end
