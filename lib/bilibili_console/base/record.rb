# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# bilibili record
module Bilibili
  # bilibili record class meta base
  class BiliBliliRecord < BiliBliliRecordBase
    def initialize(json)
      if !json.nil?
        super json
      else
        # TODO 校验表是否存在，否则创建表， 表结构根据COLUMNS字段读取
        # TODO 增加表的增删改方法和通过id查询的方法
      end
    end
  end
end