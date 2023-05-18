# coding: utf-8
# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require_relative 'api'
require_relative 'config'
require_relative 'http/http'
require_relative 'util/bilibili_utils'
require 'fileutils'
require 'open3'

# video module
module Bilibili
  include BiliHttp
  # video page list
  class PageInfo < BiliBliliRecordBase
    attr_accessor :cid, :page, :from, :part, :duration, :vid, :weblink
  end

  # bilibili video interfaces
  class Video < BilibiliBase
    def video_page_list(id)
      return nil if id.nil?

      url = "#{Api::Video::PAGE_LIST}?#{BilibiliUtils.get_id_search_param(id)}"
      datas = get_jsona(url)
      return nil if datas.nil?

      datas.map do |d|
        Bilibili::PageInfo.new(d)
      end
    end

    def get_video_url(id, cid, video_qn)
      qn = Config::VIDEO_QN[video_qn]
      url = "#{Api::Video::PLAY_URL}?#{BilibiliUtils.get_id_download_param(id)}&cid=#{cid}&qn=#{qn}&fnval=0&fnver=0&fourk=1"
      data = get_jsona(url)
      data[:durl]
    end

    # TODO 通过创建下载任务来进行视频下载
    def download_video_by_id(id, options)
      result = []
      page_list = video_page_list(id)
      return nil if page_list.nil?

      video_qn = options[:qn]
      page_list = page_slice(page_list, options[:start], options[:end], options[:page])
      $log.info("wait download size: #{page_list.size}")
      video_qn = @opt[:video_qn].to_s if video_qn.nil?
      page_list.each do |page|
        get_video_url(id, page.cid, video_qn).each do |down_url|
          order = down_url[:order] < 10 ? "0#{down_url[:order]}" : down_url[:order]
          file_name = "#{page.part}_#{order}.flv"
          file_name = "#{options[:rename]}_#{order}.flv" unless options[:rename].nil?
          url = { 'name': file_name, 'url': down_url[:url].to_s, 'prefix': page.part,
                  'order': "#{page.page}#{order}", 'id': id.to_s }
          download_path = "#{File.expand_path(@opt[:download_dir].to_s, __dir__)}/#{id}/"
          result << download_file(url, download_path)
        end
        sleep rand(3)
      end
      result
    end

    def combine_downloaded_videos(id, urls)
      return nil if urls.empty?

      download_path = "#{File.expand_path(@opt[:download_dir].to_s, __dir__)}/#{id}/"
      url_array = []
      urls.each_with_index do |u, i|
        same_part = same_part?(u, i)
        url_array << u[:file_path]
        combine_media(url_array, "#{download_path}#{u[:prefix]}.flv") unless same_part
      end
    end

    private

    def page_slice(page_list, start_page, end_page, page)
      log_info = <<~LOG
        page list size: #{page_list.size}
        start page num: #{start_page}
        end   page num: #{end_page}
        order     page: #{page}
      LOG
      $log.info(log_info)
      if page.nil?
        start_page = start_page.to_i - 1
        if end_page.nil?
          page_list.slice(start_page, page_list.size - start_page)
        elsif start_page < end_page.to_i
          page_list.slice(start_page..(end_page.to_i - 1))
        else
          raise 'start should not less than or equals to end'
        end
      else
        [] << page_list[page.to_i - 1]
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
      $log.info "开始下载视频， 视频地址：#{url[:url]}"
      headers = generate_headers
      download_and_check(url[:url], headers, dir, url[:name])
      url
    end

    def download_and_check(url, headers, dir, filename, retry_times = 0)
      $log.debug("retry times: #{retry_times}")
      file_path = "#{dir}#{filename}"
      begin
        download(url, headers['User-Agent'], headers['Referer'], headers['Cookie'], dir, filename)
        dest_file_exist?(file_path)
      rescue StandardError
        $log.error("error: #{$!} at:#{$@}")
        sleep 3
        if retry_times == 3
          raise 'retry times is 3, you should try it later'
        end
        retry_times += 1
        download_and_check(url, headers, file_path, retry_times)
      end
    end

    def check_path(dir, filename)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      "#{dir}#{filename}"
    end

    def generate_headers
      headers = BiliHttp.headers
      {
        'User-Agent' => headers[:"User-Agent"],
        'Referer' => headers[:Referer]
      }
    end

    def combine_media(files, dest)
      return if files.size.zero?

      if files.size == 1
        begin
          FileUtils.mv(files[0], dest)
        rescue StandardError
          $log.error("error: #{$!} at:#{$@}")
        end
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

    def download(url, user_agent, referer, cookie, dir, filename)
      file_path = "#{dir}#{filename}"
      puts "开始下载文件到： #{file_path}"
      $log.debug(<<~DOWNLOAD
        url:        #{url}
        user_agent: #{user_agent}
        referer:    #{referer}
        cookie:     #{cookie}
        dest:       #{file_path}
      DOWNLOAD
      )
      File.write((@opt[:cookie]).to_s, cookie) unless File.exist?((@opt[:cookie]).to_s)
      if @opt[:enable_aria2]
        aria2_download(url, user_agent, referer, dir, filename)
      else
        wget_download(url, user_agent, referer, file_path)
      end
    end

    def wget_proxy
      command = ""
      command += " -e http_proxy=\"http://#{@opt[:proxy]}\"" unless @opt[:proxy].nil?
      command += " -e https_proxy=\"https://#{@opt[:proxy]}\"" unless @opt[:proxy].nil?
      command
    end

    def aria2_proxy
      command = ""
      command += "--all-proxy=\"#{@opt[:proxy_type]}://#{@opt[:proxy]}\"" unless @opt[:proxy].nil?
      command
    end

    def wget_download(url, user_agent, referer, dest)
      command = "wget \"#{url}\" #{wget_proxy} --referer \"#{referer}\" --user-agent \"#{user_agent}\" --load-cookie=\"#{@opt[:cookie]}\" --no-check-certificate "
      $log.debug("#{command} -c -O \"#{dest}\" -t 3")
      `#{command} -c -O "#{dest}" -t 3`
    end

    def aria2_download(url, user_agent, referer, dir, filename)
      command = "aria2c #{aria2_proxy} --referer=\"#{referer}\" --user-agent \"#{user_agent}\" --load-cookies=\"#{@opt[:cookie]}\" -s #{@opt[:aria_thread_num]} --check-certificate=false \"#{url}\""
      $log.debug("#{command} -c -d \"#{dir}\" -o \"#{filename}\" --max-tries=3")
      command = "#{command} -c -d \"#{dir}\" -o \"#{filename}\" --max-tries=3"

      Open3.popen3(command) do |_stdin, stdout, _stderr, _status|
        stdout.each_line do |line|
          puts line
        end
      end
    end
  end
end
