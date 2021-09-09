# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require 'json'

# video module
module Bilibili
  include BiliHttp
  # fav list
  class FavList
    attr_accessor :count, :list, :season

    def initialize(data)
      return if data.nil?

      @count = data[:count]
      @season = data[:season]
      @list = generate_fav_list(data[:list])
    end

    def generate_fav_list(data_list)
      data = []
      if !data_list.nil? && !data_list.empty?
        data_list.each do |obj|
          data << Bilibili::FavInfo.new(obj)
        end
      end
      data
    end

    def to_json(*opt)
      {
        count: @count,
        list: @list,
        season: @season
      }.to_json(*opt)
    end
  end

  # bilibili fav info
  class FavInfo
    attr_accessor :id, :fid, :uid, :attr, :title, :fav_state, :media_count

    def initialize(json)
      return if json.nil?

      @id = json[:id]
      @fid = json[:fid]
      @uid = json[:mid]
      @attr = json[:attr]
      @title = json[:title]
      @fav_state = json[:fav_state]
      @media_count = json[:media_count]
    end

    def to_json(*opt)
      {
        id: @id,
        fid: @fid,
        uid: @uid,
        attr: @attr,
        title: @title,
        fav_state: @fav_state,
        media_count: @media_count
      }.to_json(*opt)
    end
  end

  # fav media list
  class FavResourceList
    attr_accessor :info, :medias

    def initialize(json)
      return if json.nil?

      @info = Bilibili::FavInfo.new(json[:info])
      @medias = generate_media_list(json[:medias])
    end

    def generate_media_list(medias)
      data = []
      if !medias.nil? && !medias.empty?
        medias.each do |media|
          data << Bilibili::FavMediaInfo.new(media)
        end
      end
      data
    end

    def to_json(*opt)
      {
        info: @info,
        medias: @medias
      }.to_json(*opt)
    end
  end

  # fav media info
  class FavMediaInfo
    attr_accessor :id, :type, :title, :intro, :page, :bv_id

    def initialize(json)
      return if json.nil?

      @id = json[:id]
      @type = json[:type]
      @title = json[:title]
      @intro = json[:intro]
      @page = json[:page]
      @bv_id = json[:bv_id]
    end

    def to_json(*opt)
      {
        id: @id,
        type: @type,
        title: @title,
        intro: @intro,
        page: @page,
        bv_id: @bv_id
      }.to_json(*opt)
    end
  end

  # bilibili video interfaces
  class Fav < BilibiliBase
    # list user fav folders
    def list_user_fav_video(user_info)
      url = "https://api.bilibili.com/x/v3/fav/folder/created/list-all?up_mid=#{user_info.uid}&type=2"
      data = get_jsona(url)
      Bilibili::FavList.new(data)
    end

    # list user fav folder videos by page
    def list_fav_video(media_id, page_num = 1, page_size = 10, keyword = nil)
      keyword = "&keyword=#{keyword}" unless keyword.nil?
      url = "https://api.bilibili.com/x/v3/fav/resource/list?media_id=#{media_id}&pn=#{page_num}&ps=#{page_size}#{keyword}&platform=web"
      data = get_jsona(url)
      Bilibili::FavResourceList.new(data)
    end
  end
end
