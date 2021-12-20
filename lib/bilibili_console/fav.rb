# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require_relative 'api'
require 'json'
require 'cgi'

# video module
module Bilibili
  include BiliHttp
  # fav list
  class FavList < BiliBliliRecordBase
    attr_accessor :count, :list, :season

    def list=(data_list)
      data = []
      if !data_list.nil? && !data_list.empty?
        data_list.each do |obj|
          data << Bilibili::FavInfo.new(obj)
        end
      end
      @list = data
    end
  end

  # bilibili fav info
  class FavInfo < BiliBliliRecordBase
    attr_accessor :id, :fid, :uid, :attr, :title, :fav_state, :media_count
  end

  # fav media list
  class FavResourceList < BiliBliliRecordBase
    attr_accessor :info, :medias

    def info=(json)
      @info = Bilibili::FavInfo.new(json[:info])
    end

    def medias=(medias)
      data = []
      if !medias.nil? && !medias.empty?
        medias.each do |media|
          data << Bilibili::FavMediaInfo.new(media)
        end
      end
      @medias = data
    end
  end

  # fav media info
  class FavMediaInfo < BiliBliliRecordBase
    attr_accessor :id, :type, :title, :intro, :page, :bv_id
  end

  # bilibili video interfaces
  class Fav < BilibiliBase
    # list user fav folders
    def list_user_fav_video(user_info)
      url = "#{Api::Fav::USER_FAV_LIST}?up_mid=#{user_info.mid}&type=2"
      data = get_jsona(url)
      Bilibili::FavList.new(data)
    end

    # list user fav folder videos by page
    def list_fav_video(options)
      options[:page_num] = 1 if options[:page_num].nil?
      options[:page_size] = 10 if options[:page_size].nil?
      options[:all] = 1 if options[:all].nil?
      unless options[:search].nil?
        options[:search] = "&keyword=#{CGI.escape(options[:search])}&order=mtime&type=#{options[:all]}&tid=0&jsonp=jsonp"
      end
      url = "#{Api::Fav::FAV_VIDEO_LIST}?media_id=#{options[:fav]}&pn=#{options[:page_num]}&ps=#{options[:page_size]}#{options[:search]}&platform=web"
      data = get_jsona(url)
      Bilibili::FavResourceList.new(data)
    end
  end
end
