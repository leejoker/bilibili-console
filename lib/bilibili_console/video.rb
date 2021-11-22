# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'http/http'
require 'fileutils'

# video module
module Bilibili
  include BiliHttp
  # video page list
  class PageInfo
    attr_accessor :cid, :page, :from, :part, :duration, :vid, :weblink

    def initialize(json)
      return if json.nil?

      @cid = json[:cid]
      @page = json[:page]
      @from = json[:from]
      @part = json[:part]
      @duration = json[:duration]
      @vid = json[:vid]
      @weblink = json[:weblink]
    end

    def to_json(*opt)
      {
        cid: @cid,
        page: @page,
        from: @from,
        part: @part,
        duration: @duration,
        vid: @vid,
        weblink: @weblink
      }.to_json(*opt)
    end
  end

  # bilibili video interfaces
  class Video < BilibiliBase
    def video_page_list(bv_id)
      return nil if bv_id.nil?

      url = "https://api.bilibili.com/x/player/pagelist?bvid=#{bv_id}"
      datas = get_jsona(url)
      return nil if datas.nil?

      datas.map do |d|
        Bilibili::PageInfo.new(d)
      end
    end

    def get_video_url(bv_id, cid, video_qn = '720')
      qn = BilibiliBase.video_qn[video_qn]
      url = "https://api.bilibili.com/x/player/playurl?bvid=#{bv_id}&cid=#{cid}&qn=#{qn}&fnval=0&fnver=0&fourk=1"
      data = get_jsona(url)
      data[:durl]
    end

    def video_url_list(bv_id, video_qn = '720')
      result = []
      page_list = video_page_list(bv_id)
      return nil if page_list.nil?

      page_list.each do |page|
        get_video_url(bv_id, page.cid, video_qn).each do |down_url|
          order = down_url[:order] < 10 ? "0#{down_url[:order]}" : down_url[:order]
          result << { 'name': "#{page.part}_#{order}.flv", 'url': down_url[:url].to_s, 'prefix': page.part,
                      'order': "#{page.page}#{order}", 'bv': bv_id.to_s }
        end
      end
      result
    end

    def download_video_by_bv(bv_id, video_qn = '720', start = 1, page = nil)
      urls = video_url_list(bv_id, video_qn)
      return nil if urls.empty?

      urls = page_slice(urls, start.to_i - 1, page)
      download_path = "#{File.expand_path(@options['download_path'].to_s, __dir__)}/#{bv_id}/"
      url_array = []
      urls.map { |url| download_file(url, download_path) }.each_with_index do |u, i|
        same_part = same_part?(u, i)
        url_array << u[:file_path]
        combine_media(url_array, "#{download_path}#{u[:prefix]}.flv") unless same_part
      end
    end

    private

    def page_slice(urls, start, page)
      if page.nil?
        urls.slice(start, urls.size - start)
      else
        [] << urls[page.to_i - 1]
      end
    end

    def next?(array, index)
      !array[index + 1].nil?
    end

    def same_part?(array, idx)
      next?(array, idx) && array[idx][:prefix] == array[idx + 1][:prefix]
    end

    def download_file(url, dir)
      file_path = check_path(dir, url[:name])
      url[:file_path] = file_path
      puts "开始下载文件到： #{file_path}, 视频地址：#{url[:url]}"
      headers = generate_headers
      wget_download(url[:url], headers['User-Agent'], headers['Referer'], headers['Cookie'], file_path)
      dest_file_exist?(file_path)
      url
    end

    def check_path(dir, filename)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      "#{dir}#{filename}"
    end

    def create_cookie_str(cookies)
      cookie_array = cookies['/'].map do |key, value|
        "#{key}=#{value}; "
      end
      cookie_array.join
    end

    def generate_headers
      headers = BiliHttp.headers
      {
        'User-Agent' => headers[:"User-Agent"],
        'Referer' => headers[:Referer],
        'Cookie' => create_cookie_str(load_cookie)
      }
    end

    def combine_media(files, dest)
      return if files.size.zero?

      if files.size == 1
        FileUtils.mv(files[0], dest)
        files.clear
        return
      end

      return if files.select! { |file| File.exist?(file) }.size.zero?

      `ffmpeg -i concat:"#{files.join('|')}" -c copy #{dest}`
      files.clear
    end

    def dest_file_exist?(dest)
      if File.exist?(dest)
        local = File.new(dest).size
        raise 'file size is zero' if local.zero?

        true
      else
        false
      end
    end

    def wget_file_size(command)
      result = `#{command} -o -`
      hash = {}
      result.split("\n").filter { |n| n.include?(':') }.each do |line|
        a = line.split(':')
        hash[a[0].strip] = a[1].strip
      end
      hash['Content-Length'].to_i
    end

    def wget_download(url, user_agent, referer, cookie, dest)
      config_path = File.expand_path((@options['config_path']).to_s, __dir__)
      File.write("#{config_path}/cookie", cookie) unless File.exist?("#{config_path}/cookie")
      command = "wget '#{url}' --referer '#{referer}' --user-agent '#{user_agent}' --load-cookie='#{config_path}/cookie' "
      `#{command} -c -O "#{dest}"`
    end
  end
end
