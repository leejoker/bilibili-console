# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'api'

# bilibili video comments
module Bilibili
  include BiliHttp

  # cursor data
  class Cursor < BiliBliliRecordBase
    attr_accessor :all_count, :is_begin, :prev, :next, :is_end, :mode, :show_type, :support_mode, :name
  end

  # comment reply
  class CommentReply < BiliBliliRecordBase
    attr_accessor :rpid, :oid, :type, :mid, :root, :ctime, :member, :content

    def member=(json)
      return if json.nil?

      @member = {
        mid: json[:mid],
        uname: json[:uname],
        avatar: json[:avatar],
        level_info: json[:level_info][:current_level]
      }
    end

    def content=(json)
      return if json.nil?

      @content = {
        message: json[:message],
        pictures: json[:pictures]
      }
    end
  end

  # comment response data
  class CommentPage < BiliBliliRecordBase
    attr_accessor :cursor, :hots, :notice, :replies, :top, :top_replies, :lottery_card, :folder, :upper, :show_bvid

    def hots=(json)
      data = []
      if !json.nil? && !json.empty?
        json.each do |hot|
          comment = CommentReply.new(hot)
          data << comment if comment.root.zero?
        end
      end
      @hots = data
    end

    def replies=(json)
      data = []
      if !json.nil? && !json.empty?
        json.each do |reply|
          comment = CommentReply.new(reply)
          data << comment if comment.root.zero?
        end
      end
      @replies = data
    end
  end

  # comment class
  class Comment < BilibiliBase

    # get comment list
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