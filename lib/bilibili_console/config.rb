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
      base_path: "#{Dir.home}/.bc",
      config_file: "#{Dir.home}/.bc/bilic.conf",
      cookie_json: "#{Dir.home}/.bc/cookie.json",
      cookie: "#{Dir.home}/.bc/cookie.txt",
      ssl: true,
      port: 443,
      request_log: false,
      video_qn: '720',
      save_video_pic: false,
      enable_aria2: false,
      aria_thread_num: 3,
      log_file: "#{Dir.home}/.bc/bilic.log",
      log_level: 'debug',
      download_dir: "#{Dir.home}/.bc/downloads",
      video_pic_dir: "#{Dir.home}/.bc/pic",
      db_file_path: "#{Dir.home}/.bc/bilic.db",
      tmp_dir: "#{Dir.home}/.bc/tmp",
      proxy_type: 'http',
      proxy: nil
    }.freeze

    VIDEO_QN = {
      '240' => 6, '360' => 16, '480' => 32, '720' => 64, '720P60' => 74, '1080' => 80,
      '1080+' => 112, '1080P60' => 116, '4K' => 120, 'HDR' => 125
    }.freeze

    def initialize(*config_file)
      @options = Config::DEFAULT_OPTIONS.dup
      conf = config_file.empty? ? @options[:config_file] : config_file[0]
      config_info = File.read(conf) if File.exist?(conf)
      @options.merge!(JSON.parse(config_info, symbolize_names: true)) unless config_info.nil? || config_info.length.zero?
      check_paths

      $log = Logger.new(File.new(@options[:log_file], 'a+'))
      $log.level = @options[:log_level]
      $log.debug("config info: #{@options}")
    end

    private

    def check_paths
      check_file(@options[:cookie_json])
      check_file(@options[:cookie])
      check_file(@options[:log_file])
      FileUtils.mkdir_p(@options[:download_dir]) unless Dir.exist?(@options[:download_dir])
      FileUtils.mkdir_p(@options[:video_pic_dir]) unless Dir.exist?(@options[:video_pic_dir])
      FileUtils.mkdir_p(@options[:tmp_dir]) unless Dir.exist?(@options[:tmp_dir])
    end

    def check_file(path)
      absolute_path = File.expand_path(path, __FILE__)
      basename = File.basename(absolute_path)
      dirname = absolute_path.sub(basename, '')
      FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)
    end
  end
end
