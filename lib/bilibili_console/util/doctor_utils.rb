# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'nokogiri'
require 'zip'

module Bilibili
  # doctor util for bilibili_console
  # TODO 增加提示，暂时不提供非window或linux系统的aria2安装支持
  class Doctor
    class << self
      def bilic_dir
        result = `where bilic`
        file_array = result.to_s.split("\n")
        File.dirname(file_array[0])
      end

      def download_file(url, file_path)
        puts "Url: #{url}, filePath: #{file_path}"
        uri = URI(url)
        http_client = BiliHttp::BiliHttpClient.new(443, true, BilibiliBase.proxy)
        http_client.get_stream({ path: uri, save_data: file_path })
        yield file_path
      end

      def check_wget
        return unless windows_command_check('wget')

        puts 'Starting download wget.exe'
        download_file('https://eternallybored.org/misc/wget/1.21.3/64/wget.exe', "#{bilic_dir}#{File::ALT_SEPARATOR}wget.exe") do |path|
          puts 'wget.exe installed'
        end
      end

      def check_aria2
        if Bilibili.os == :windows
          return unless windows_command_check('aria2c')
          download_aria2_windows
        elsif Bilibili.os == :linux
          return unless linux_command_check('aria2c')
          install_aria2_linux
        else
          puts '暂不支持windows及linux意外的发行版'
        end
      end

      def download_aria2_windows
        http_client = BiliHttp::BiliHttpClient.new(443, true, BilibiliBase.proxy)
        doc = Nokogiri::HTML(http_client.get({ path: URI('https://github.com/aria2/aria2') }))
        node_set = doc.xpath('//*[@id="repo-content-pjax-container"]/div/div/div[2]/div[2]/div/div[2]/div/a')
        return if node_set.nil?

        href = node_set[0]&.attr('href')
        version = href[href.index('-') + 1..]
        os_bit = Bilibili.os_bit
        dir = bilic_dir
        filename = "aria2-#{version}-win-#{os_bit}bit-build1"
        puts 'Starting download aria2'
        download_file("https://github.com/aria2/aria2/releases/download/release-#{version}/#{filename}.zip",
                      "#{dir}#{File::ALT_SEPARATOR}#{filename}.zip") do |path|
          puts 'aria2 downloaded'
          File.open("#{dir}/aria2c.exe", 'wb') do |file|
            Zip::File.open(path) do |zip_file|
              entry = zip_file.glob("#{filename}/aria2c.exe").first
              entry.get_input_stream do |f|
                file.write(f.read)
              end
            end
          end
          File.delete(path)
          puts 'aria2 installed'
        end
      end

      private

      def install_aria2_linux
        linux_type = Bilibili.linux_distribution
        case linux_type
        when :debian
          `sudo apt install aria2`
        when :centos
          `sudo yum install aria2`
        when :arch
          `sudo pacman -Sy aria2`
        else
          puts 'unknown linux distribution'
        end
      end

      def windows_command_check(command)
        return false unless Bilibili.os == :windows

        puts "Start check #{command}"
        result = `where #{command}`
        if result.nil? || result.to_s == ''
          true
        else
          puts "#{command} installed"
          false
        end
      end

      def linux_command_check(command)
        return false unless Bilibili.os == :linux

        puts "Start check #{command}"
        result = `command -v #{command}`
        if result.nil? || result.to_s == ''
          true
        else
          puts "#{command} installed"
          false
        end
      end
    end
  end
end
