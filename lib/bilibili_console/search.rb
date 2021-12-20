# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'api'

# search module
module Bilibili
  include BiliHttp

  class VideoResult
    attr_accessor :author, :mid, :typename, :bvid, :title, :description, :pic
  end

  # search result data
  class SearchData
    attr_accessor :seid, :page, :pageSize, :numResults, :numPages, :suggest_keyword, :result

    def generate_result

    end
  end

  # search result list
  class SearchList
    attr_accessor :data

    def initialize(json)
      return if json.nil?

      @data = Bilibili::SearchData.new(json[:data])
    end

    def to_json(*opt)
      {
        data: @data
      }.to_json(*opt)
    end
  end

  # bilibili search interfaces
  class Search < BilibiliBase
    def search(options)
      url = "#{Api::Search::TYPE}?search_type=video&keyword=#{CGI.escape(options[:keyword])}&page=#{options[:page]}"
      data = get_jsona(url)
    end
  end
end