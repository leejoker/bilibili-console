# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'base'
require_relative 'api'

# search module
module Bilibili
  include BiliHttp

  # search result data
  class SearchData < BiliBliliRecordBase
    attr_accessor :seid, :page, :pageSize, :numResults, :numPages, :suggest_keyword, :result

    def result=(videos)
      data = []
      if !videos.nil? && !videos.empty?
        videos.each do |video|
          data << Bilibili::VideoResult.new(video)
        end
      end
      @result = data
    end
  end

  class VideoResult < BiliBliliRecordBase
    attr_accessor :author, :aid, :bvid, :title, :description, :pic
  end

  # bilibili search interfaces
  class Search < BilibiliBase
    def search(options)
      url = "#{Api::Search::TYPE}?search_type=video&keyword=#{CGI.escape(options[:keyword])}"
      url += "&page=#{options[:page]}" unless options[:page].nil?
      data = Bilibili::SearchData.new(get_jsona(url))
      bv_filter(data, options)
      cover_save(data, options)
      data
    end

    private

    def bv_filter(data, options)
      data&.result&.select! do |v|
        if options.key? :bv
          v.bvid.to_s == options[:keyword].to_s
        else
          true
        end
      end
    end

    def cover_save(data, options)
      return unless options.key?(:pic) && options.key?(:bv)

      uri = URI("https:#{data.result[0].pic}")
      http = NiceHttp.new(host: "https://#{uri.host}", ssl: true)
      http.get(uri.request_uri, save_data: "#{@opt[:video_pic_dir]}/COVER_#{data.result[0].bvid}.jpg")
    end
  end
end
