# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#

require_relative '../http/http'
require 'rqrcode'
require 'json'

module AliyunDrive
  QRCODE_URL = 'https://passport.aliyundrive.com/newlogin/qrcode/generate.do?appName=aliyun_drive&fromSite=52&appName=aliyun_drive&appEntrance=web&_csrf_token=M1hQFtyi3Zh5Act6rECMJ2&umidToken=c482ae89df6b01a3487f4a4c64f79375acabd28a&isMobile=false&lang=zh_CN&returnUrl=&hsiz=1172660bbf4ed02710b7eba8b7f8b363&fromSite=52&bizParams=&_bx-v=2.0.31'
  QRCODE_QUERY = 'https://passport.aliyundrive.com/newlogin/qrcode/query.do?appName=aliyun_drive&fromSite=52&_bx-v=2.0.31'
  USER_INFO = 'https://api.aliyundrive.com/v2/user/get'
end
