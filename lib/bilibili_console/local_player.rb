# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# local media player launcher
module Bilibili
  # resolves and starts a local media player without going through the shell
  class LocalPlayer
    CANDIDATES = %w[mpv vlc xdg-open].freeze

    def initialize(command = nil)
      @command = command.to_s.strip
    end

    def command
      return @command unless @command.empty?

      CANDIDATES.each do |name|
        path = path_lookup(name)
        return path if path
      end
      nil
    end

    def play(url)
      player = command
      raise '未找到本地播放器，请安装 mpv/vlc 或在 ~/.bc/bilic.conf 配置 "player"' if player.nil?
      raise '播放地址为空，无法播放' if url.to_s.empty?

      system(player, url)
    end

    private

    def path_lookup(name)
      ENV['PATH'].to_s.split(File::PATH_SEPARATOR).each do |dir|
        candidate = File.join(dir, name)
        return candidate if File.executable?(candidate)
      end
      nil
    end
  end
end
