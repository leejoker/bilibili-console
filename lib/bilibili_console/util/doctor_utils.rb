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

      def download_by_powershell(url, file_path)
        puts "Url: #{url}, filePath: #{file_path}"
        `powershell.exe -c wget -Uri #{url} -OutFile #{file_path}`
      end

      def check_wget
        return unless Bilibili.os == :windows

        puts 'Start check wget'
        result = `where wget.exe > nul 2> nul`
        return unless result.nil? || result.to_s == ''

        puts 'Starting download wget.exe'
        download_by_powershell('https://eternallybored.org/misc/wget/1.21.3/64/wget.exe', " #{bilic_dir}/wget.exe")
        puts 'wget.exe installed'
      end

      def check_aria2
        if Bilibili.os == :windows
          download_aria2_windows
        elsif Bilibili.os == :linux
          install_aria2_linux
        else
          puts '暂不支持windows及linux意外的发行版'
        end
      end

      private

      def download_aria2_windows
        http_client = NiceHttp.new('https://github.com')
        doc = Nokogiri::HTML(http_client.get({ path: URI('https://github.com/aria2/aria2').request_uri }).data)
        node_set = doc.xpath('//*[@id="repo-content-pjax-container"]/div/div/div[3]/div[2]/div/div[2]/div/a')
        return if node_set.nil?

        href = node_set[0]&.attr('href')
        version = href[href.index('-') + 1..]
        os_bit = Bilibili.os_bit
        dir = bilic_dir
        filename = "aria2-#{version}-win-#{os_bit}bit-build1.zip"
        puts 'Starting download aria2'
        download_by_powershell("https://github.com/aria2/aria2/releases/download/release-#{version}/#{filename}",
                               "#{dir}/#{filename}")
        puts 'aria2 downloaded'
        content = Zip::File.open("#{dir}/#{filename}") do |zip_file|
          entry = zip_file.glob('aria2c.exe').first
          entry.get_input_stream.read
        end
        File.open("#{dir}/aria2c.exe", "wb+") do |file|
          file.syswrite(content)
        end
        puts 'aria2 installed'
      end

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
    end
  end
end
