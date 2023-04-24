# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'api'

# bilibili video comments
module Bilibili
  include BiliHttp

  class Cursor < BiliBliliRecordBase
    attr_accessor :all_count, :is_begin, :prev, :next, :is_end, :mode, :show_type, :support_mode, :name
  end

  class CommentReply < BiliBliliRecordBase
    attr_accessor :rpid, :oid, :type, :mid, :root, :ctime, :member, :content

    def member=(json)
      @member = json[:member]
    end

    def content=(json)
      @content = json[:content]
    end
  end

  class CommentPage < BiliBliliRecordBase
    attr_accessor :cursor, :hots, :notice, :replies, :top, :top_replies, :lottery_card, :folder, :upper, :show_bvid

    def cursor=(json)
      @cursor = Cursor.new(json[:cursor])
    end

    def hots=(json)
      data = []
      if !json.nil? && !json.empty?
        json.each do |hot|
          data << CommentReply.new(hot)
        end
      end
      @hots = data
    end

    def replies=(json)
      data = []
      if !json.nil? && !json.empty?
        json.each do |reply|
          data << CommentReply.new(reply)
        end
      end
      @replies = data
    end
  end

  class Comment < BilibiliBase
    def comment_list(options)
      nil if options.nil?

      type = options[:type]
      oid = options[:oid]
      mode = options[:mode].nil? ? nil : options[:mode]
      page = options[:page].nil? ? nil : options[:page]
      size = options[:size].nil? ? nil : options[:size]

      url = "#{Api::Comment::COMMENT_LAZY}?#{get_comment_list_param(type, oid, mode, page, size)}"

      data = get_jsona(url)
      return nil if data.nil?

      CommentPage.new(data)
    end

    private

    def get_comment_list_param(type, oid, mode = 3, page = 0, size = 10)
      url = "type=#{type}&oid=#{oid}"
      url.concat("&mode=#{mode}") unless mode.nil?
      url.concat("&next=#{page}") unless page.nil?
      url.concat("&ps=#{size}") unless size.nil?

      url
    end
  end
end