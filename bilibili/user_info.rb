# frozen_string_literal: true

# bilibili module
module Bilibili
  # bilibili user info
  class UserInfo
    attr_accessor :face, :level_info, :uid, :money, :moral, :uname, :vip_type

    def init_attrs(json)
      return unless json.nil?

      @face = json['face']
      @level_info = json['level_info']
      @uid = json['mid']
      @money = json['money']
      @moral = json['moral']
      @uname = json['uname']
      @vip_type = json['vipType']
    end
  end
end
