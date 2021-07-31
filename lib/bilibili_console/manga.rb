# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'

# video module
module Bilibili
  include BiliHttp
  
  # bilibili video interfaces
  class Manga < BilibiliBase
    def check_in
      user_agent <<~AGENT
        Mozilla/5.0 BiliDroid/6.4.0 (bbcallen@gmail.com) os/android model/M1903F11I mobi_app/android build/6040500 channel/bili innerVer/6040500 osVer/9.0.0 network/2
      AGENT
      cur_header = {}
      cur_header['User-Agent'] = user_agent
      post_jsonm('https://manga.bilibili.com/twirp/activity.v1.Activity/ClockIn', cur_header,
                 { 'platform' => 'android' })
    end
  end
end
