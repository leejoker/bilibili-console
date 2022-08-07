# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# bilibili base
module Bilibili
  # bilibili record class meta base
  class BiliBliliRecordBase
    def initialize(json)
      if !json.nil?
        hash = {}
        public_methods(false).filter { |m| m.to_s.index('=').nil? }.each do |method|
          next if json[method.to_s.to_sym].nil?

          value = method("#{method.to_s}=".to_sym).call(json[method.to_s.to_sym])
          hash.merge!({ method.to_s => value })
        end

        BiliBliliRecordBase.define_method('to_json') do |*opt|
          hash.to_json(*opt)
        end
      else
        # TODO 校验表是否存在，否则创建表， 表结构根据COLUMNS字段读取
        # TODO 增加表的增删改方法和通过id查询的方法
      end
    end
  end
end
