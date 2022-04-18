# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  # 任务管理类
  # status 0 未开始 1 下载中 2 已暂停
  class Task < BiliBliliRecordBase
    attr_accessor :id, :url, :status, :bv, :cur_part, :cur_percent, :total_percent
  end
end