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
        result = `where wget.exe`
        return unless result.nil? || result.to_s.equal?('')

        puts 'Starting download wget.exe'
        `powershell -c wget -Uri https://eternallybored.org/misc/wget/1.21.3/64/wget.exe -OutFile wget.exe`
        puts 'download wget.exe over'
      end
    end
  end
end
