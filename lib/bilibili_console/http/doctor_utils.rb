# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Bilibili
  # doctor util for bilibili_console
  class Doctor
    class << self
      def check_wget
        result = `where wget.exe > nul 2> nul`
        puts "result: #{result}"
        return unless result.nil? || result.to_s == ''

        puts 'Starting download wget.exe'
        result = `where bilic`
        file_array = result.to_s.split("\n")
        dir = File.dirname(file_array[0])
        `powershell.exe -c wget -Uri https://eternallybored.org/misc/wget/1.21.3/64/wget.exe -OutFile #{dir}/wget.exe`
        puts 'wget.exe installed'
      end
    end
  end
end
