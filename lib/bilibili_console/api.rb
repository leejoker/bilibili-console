# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  module Api
    LOGIN_HOST = 'https://passport.bilibili.com'
    API_HOST = 'https://api.bilibili.com'
    MANGA_HOST = 'https://manga.bilibili.com'

    module Login
      QRCODE = "#{LOGIN_HOST}/qrcode/getLoginUrl"
      INFO = "#{LOGIN_HOST}/qrcode/getLoginInfo"
      USERINFO = "#{API_HOST}/nav"
    end

    module Fav
      USER_FAV_LIST = "#{API_HOST}/x/v3/fav/folder/created/list-all"
      FAV_VIDEO_LIST = "#{API_HOST}/x/v3/fav/resource/list"
    end

    module Video
      PAGE_LIST = "#{API_HOST}/x/player/pagelist"
      PLAY_URL = "#{API_HOST}/x/player/playurl"
    end

    module Manga
      CHECK_IN = "#{MANGA_HOST}/twirp/activity.v1.Activity/ClockIn?platform=android"
    end

    module Search
      TYPE = "#{API_HOST}/x/web-interface/search/type"
    end
  end
end