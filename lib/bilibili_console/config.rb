# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require 'fileutils'
require 'json'
require 'logger'

# bilibili
module Bilibili
  # bilibili_console config class
  class Config
    attr_accessor :options

    DEFAULT_OPTIONS = {
      config_file: '~/.bc/bilic.conf',
      cookie_json: 'cookie.json',
      cookie: 'cookie.txt',
      video_qn: '720',
      log_file: 'bilic.log',
      download_dir: 'downloads'
    }.freeze

    def initialize(*config_file)
      @options = DEFAULT_OPTIONS.dup if config_file.nil?
    end
  end
end