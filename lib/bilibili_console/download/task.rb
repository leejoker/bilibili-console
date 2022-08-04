# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  # 任务管理类
  # status 0 未开始 1 下载中 2 已暂停
  class Task < BiliBliliRecordBase
    attr_accessor :id, :status, :bv, :cur_part, :cur_percent, :total_percent

    def add_task(task)

    end

    def clean_completed

    end

    def stop_task(id)

    end

    def continue_task(id)

    end

    def delete_task(id)

    end
  end

  class SubTask < BiliBliliRecordBase
    attr_accessor :id, :url, :status, :cur_percent, :task_id

    def add_sub_task(sub_task)

    end

    def clean_completed

    end

    def stop_all_sub_task(task_id)

    end

    def continue_all_sub_task(task_id)

    end

    def delete_sub_task(id)

    end

    private

    def run_download(id)

    end

    def refresh_status(id)

    end
  end
end