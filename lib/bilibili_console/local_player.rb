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
    # B 站 CDN 直链只认带 Referer 的请求，裸 GET 一律 403
    REFERER = 'https://www.bilibili.com/'
    USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' \
                 'Chrome/131.0.0.0 Safari/537.36'

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
      if player.nil?
        raise '未找到本地播放器：请安装 mpv/vlc，或在 ~/.bc/bilic.conf 里配置 "player"，' \
              '也可以用 bilic play <bvid> --no-launch 拿到直链自行播放'
      end
      raise '播放地址为空，无法播放' if url.to_s.empty?

      system(*launch_args(player, url))
    end

    private

    # mpv / vlc 支持自定义请求头，其它播放器只能裸地址（B 站 CDN 会 403）
    def launch_args(player, url)
      name = File.basename(player.to_s).downcase
      if name.start_with?('mpv')
        [player, url, "--user-agent=#{USER_AGENT}", "--http-header-fields=Referer: #{REFERER}"]
      elsif name.start_with?('vlc')
        [player, url, "--http-referrer=#{REFERER}", "--http-user-agent=#{USER_AGENT}"]
      else
        [player, url]
      end
    end

    def path_lookup(name)
      ENV['PATH'].to_s.split(File::PATH_SEPARATOR).each do |dir|
        candidate = File.join(dir, name)
        return candidate if File.executable?(candidate)
      end
      nil
    end
  end
end
