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
      QRCODE = "#{LOGIN_HOST}/x/passport-login/web/qrcode/generate"
      INFO = "#{LOGIN_HOST}/x/passport-login/web/qrcode/poll"
      USERINFO = "#{API_HOST}/x/web-interface/nav"
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
      CHECK_IN = "#{MANGA_HOST}/twirp/activity.v1.Activity/ClockIn"
      CHECK_IN_INFO = "#{MANGA_HOST}/twirp/activity.v1.Activity/GetClockInInfo"
    end

    module Search
      TYPE = "#{API_HOST}/x/web-interface/search/type"
    end

    module Comment
      COMMENT_LAZY = "#{API_HOST}/x/v2/reply/main"
    end
  end
end