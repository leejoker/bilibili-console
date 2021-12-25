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
      base_path: '~/.bc',
      config_file: "#{DEFAULT_OPTIONS[:base_path]}/bilic.conf",
      cookie_json: "#{DEFAULT_OPTIONS[:base_path]}/cookie.json",
      cookie: "#{DEFAULT_OPTIONS[:base_path]}/cookie.txt",
      video_qn: '720',
      log_file: "#{DEFAULT_OPTIONS[:base_path]}/bilic.log",
      download_dir: "#{DEFAULT_OPTIONS[:base_path]}/downloads"
    }.freeze

    VIDEO_QN = {
      '240' => 6, '360' => 16, '480' => 32, '720' => 64, '720P60' => 74, '1080' => 80,
      '1080+' => 112, '1080P60' => 116, '4K' => 120, 'HDR' => 125
    }.freeze

    def initialize(*config_file)
      @options = DEFAULT_OPTIONS.dup
      conf = config_file.nil? ? @options[:config_file] : config_file[0]
      config_info = File.read(conf) if File.exists?(conf)
      @options.merge!(JSON.parse(config_info)) unless config_info.nil?
      check_paths
    end

    private

    def check_paths
      check_file(@options[:cookie_json])
      check_file(@options[:cookie])
      check_file(@options[:log_file])
      FileUtils.mkdir_p(@options[:download_dir]) unless Dir.exist?(@options[:download_dir])
    end

    def check_file(path)
      absolute_path = File.expand_path(path, __FILE__)
      basename = File.basename(absolute_path)
      dirname = absolute_path.sub(basename, '')
      FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)
    end
  end
end