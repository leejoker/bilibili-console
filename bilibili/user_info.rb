# frozen_string_literal: true

require 'json'

# bilibili module
module Bilibili
  # bilibili user info
  class UserInfo
    attr_accessor :face, :level_info, :uid, :money, :moral, :uname, :vip_type

    def init_attrs(json)
      @face = json[:face]
      @level_info = json[:level_info]
      @uid = json[:mid]
      @money = json[:money]
      @moral = json[:moral]
      @uname = json[:moral]
      @vip_type = json[:vipType]
    end

    def to_json(*options)
      as_json(*options).to_json(*options)
    end

    def as_json(_options = {})
      {
        face: @face,
        level_info: @level_info,
        uid: @uid,
        money: @money,
        moral: @moral,
        uname: @uname,
        vip_type: @vip_type
      }
    end
  end
end
