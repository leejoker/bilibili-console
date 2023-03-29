# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  class BilibiliUtils
    class << self
      def get_av_code(av_id_str)
        return av_id_str if av_id_str.to_s.include?('BV')

        av_id_str.to_s.slice(2..-1) if av_id_str.to_s.include?('av')
      end

      def get_id_search_param(id)
        return "bvid=#{id}" if id.to_s.include?('BV')

        "aid=#{BilibiliUtils.get_av_code(id)}" if id.to_s.include?('av')
      end

      def get_id_download_param(id)
        return "bvid=#{id}" if id.to_s.include?('BV')

        "avid=#{BilibiliUtils.get_av_code(id)}" if id.to_s.include?('av')
      end
    end
  end
end