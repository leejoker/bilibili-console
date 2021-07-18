# Copyright (c) 2021 10344742
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  VERSION = '0.0.1'.freeze
  OPTIONS = {
    'config_path' => '~/.bc',
    'config_file' => "#{OPTIONS['config_path']}/config.json",
    'cookie_file' => "#{OPTIONS['config_path']}/cookie.txt",
    'download_path' => '~/.bc/download'
  }.freeze
end
