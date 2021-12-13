# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  module Api
    module Login
      QRCODE = 'https://passport.bilibili.com/qrcode/getLoginUrl'
      INFO = 'https://passport.bilibili.com/qrcode/getLoginInfo'
      USERINFO = 'https://api.bilibili.com/nav'
    end

    module Fav
      USER_FAV_LIST = 'https://api.bilibili.com/x/v3/fav/folder/created/list-all'
      FAV_VIDEO_LIST = 'https://api.bilibili.com/x/v3/fav/resource/list'
    end

    module Video
      PAGE_LIST = 'https://api.bilibili.com/x/player/pagelist'
      PLAY_URL = 'https://api.bilibili.com/x/player/playurl'
    end

    module Manga
      CHECK_IN = 'https://manga.bilibili.com/twirp/activity.v1.Activity/ClockIn?platform=android'
    end
  end
end