# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'base/base'
require_relative 'api'
require 'time'

# watch history module
module Bilibili
  include BiliHttp

  # one watch history record
  class HistoryItem
    attr_reader :title, :bvid, :cid, :page, :part, :author_name, :author_mid,
                :progress, :duration, :view_at, :business, :uri

    def initialize(raw)
      history = raw[:history] || {}
      @title = raw[:title].to_s
      @bvid = history[:bvid].to_s
      @cid = history[:cid]
      @page = history[:page]
      @part = history[:part].to_s
      @author_name = raw[:author_name].to_s
      @author_mid = raw[:author_mid]
      @progress = raw[:progress].to_i
      @duration = raw[:duration].to_i
      @view_at = raw[:view_at].to_i
      @business = raw[:business].to_s
      @uri = raw[:uri].to_s
    end

    def viewed_at
      Time.at(@view_at).localtime.strftime('%Y-%m-%d %H:%M:%S')
    end

    def progress_percent
      return 0 if @duration.zero?

      ((@progress.to_f / @duration) * 100).round(1)
    end
  end

  # bilibili watch history interfaces
  class History < BilibiliBase
    DEFAULT_COUNT = 20

    def list(options = {})
      count = (options[:count] || DEFAULT_COUNT).to_i
      page = (options[:page] || 1).to_i
      cursor = { max: 0, view_at: 0, business: '' }
      items = []

      page.times do
        data = fetch(cursor, count)
        return items if data.nil?

        rows = data[:list]
        return items if rows.nil? || rows.empty?

        items = rows.map { |row| HistoryItem.new(row) }
        cursor = data[:cursor] || cursor
      end

      items
    end

    private

    def fetch(cursor, count)
      query = "ps=#{count}"
      query += "&max=#{cursor[:max]}" if cursor[:max].to_i.positive?
      query += "&view_at=#{cursor[:view_at]}" if cursor[:view_at].to_i.positive?
      query += "&business=#{cursor[:business]}" unless cursor[:business].to_s.empty?
      get_jsona("#{Api::History::CURSOR}?#{query}")
    end
  end
end
