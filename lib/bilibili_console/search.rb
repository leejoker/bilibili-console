# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'base'
require_relative 'api'
require_relative 'video'

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
    attr_accessor :author, :aid, :bvid, :title, :description, :pic, :page_size
  end

  # bilibili search interfaces
  class Search < BilibiliBase
    def search(options)
      sort_type = options[:sort]
      url = "#{Api::Search::TYPE}?search_type=video&keyword=#{CGI.escape(options[:keyword])}"
      url += "&page=#{options[:page]}" unless options[:page].nil?
      url += "&order=#{sort_type}" unless sort_type.nil?
      data = Bilibili::SearchData.new(get_jsona(url))
      bv_filter(data, options)
      cover_save(data, options)
      get_pages(data)
      data
    end

    private

    def bv_filter(data, options)
      data&.result&.select! do |v|
        options[:bv] ? v.bvid.to_s == options[:keyword].to_s : true
      end
    end

    def cover_save(data, options)
      return unless options[:pic] && options[:bv]

      uri = URI("https:#{data.result[0].pic}")
      http = NiceHttp.new(host: "https://#{uri.host}", ssl: true)
      http.get(uri.request_uri, save_data: "#{@opt[:video_pic_dir]}/COVER_#{data.result[0].bvid}.jpg")
    end

    def get_pages(data)
      data&.result&.collect! do |v|
        video = Bilibili::Video.new
        v.page_size = video.video_page_list(v.bvid)&.size
        v
      end
    end
  end
end
