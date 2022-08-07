# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'nokogiri'

module Bilibili
  # doctor util for bilibili_console
  # TODO 增加提示，暂时不提供非window或linux系统的aria2安装支持
  class Doctor
    class << self
      def check_wget
        return unless Bilibili.os == :windows

        puts 'Start check wget'
        result = `where wget.exe > nul 2> nul`
        return unless result.nil? || result.to_s == ''

        puts 'Starting download wget.exe'
        result = `where bilic`
        file_array = result.to_s.split("\n")
        dir = File.dirname(file_array[0])
        `powershell.exe -c wget -Uri https://eternallybored.org/misc/wget/1.21.3/64/wget.exe -OutFile #{dir}/wget.exe`
        puts 'wget.exe installed'
      end

      def check_aria2
        if Bilibili.os == :windows

        else

        end
      end

      private

      def download_aria2_windows
        doc = Nokogiri::HTML(URI.open('https://github.com/aria2/aria2'))
        node_set = doc.xpath('//*[@id="repo-content-pjax-container"]/div/div/div[3]/div[2]/div/div[2]/div/a')
        return if node_set.nil?

        href = node_set[0]&.attr('href')
        version = href[href.index('-') + 1..]
        os_bit = Bilibili.os_bit
        download_url = "https://github.com/aria2/aria2/releases/download/release-#{version}/aria2-#{version}-win-#{os_bit}bit-build1.zip"
        # TODO
      end

      def install_aria2_linux
        # TODO
      end
    end
  end
end
