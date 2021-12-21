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
    attr_accessor :author, :bvid, :title, :description, :pic
  end

  # bilibili search interfaces
  class Search < BilibiliBase
    def search(options)
      url = "#{Api::Search::TYPE}?search_type=video&keyword=#{CGI.escape(options[:keyword])}"
      url += "&page=#{options[:page]}" unless options[:page].nil?
      data = get_jsona(url)
      Bilibili::SearchData.new(data)
    end
  end
end
