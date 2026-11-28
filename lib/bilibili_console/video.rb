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

  class VideoInfo < BiliBliliRecordBase
    attr_accessor :title, :pic, :owner, :videos
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

    def get_video_info(id)
      url = "#{Api::Video::VIDEO_INFO}?bvid=#{id}"
      data = get_jsona(url)
      return nil if data.nil?

      Bilibili::VideoInfo.new(data)
    end

    # download (or resume) the video as a persisted task
    def download_video_by_id(id, options = {})
      task = store.find_open_by_bvid(id) || build_task(id, options)
      return nil if task.nil?

      DownloadTaskRunner.new(task, store, self, workers: options[:workers]).run
    end

    def tasks
      store.all.sort_by { |task| -task.updated_at }
    end

    def find_task(id)
      store.find(id)
    end

    def retry_task(id, options = {})
      task = store.find(id)
      return nil if task.nil?

      task.segments.each { |segment| segment[:status] = 'pending' if segment[:status] == 'failed' }
      task.status = 'pending'
      task.error = ''
      store.save(task)
      DownloadTaskRunner.new(task, store, self, workers: options[:workers]).run
    end

    def cancel_task(id)
      task = store.find(id)
      return nil if task.nil?
      return task if task.done?

      task.status = 'canceling'
      store.save(task)
      task
    end

    def remove_task(id)
      store.delete(id)
    end

    # resolve a playable url for one page of the video
    def play_url(id, options = {})
      page_list = video_page_list(id)
      return nil if page_list.nil? || page_list.empty?

      page = (options[:page] || 1).to_i
      info = page_list[page - 1]
      return nil if info.nil?

      qn = options[:qn] || @opt[:video_qn].to_s
      urls = get_video_url(id, info.cid, qn)
      return nil if urls.nil? || urls.empty?

      { url: urls.first[:url].to_s, title: get_video_info(id)&.title.to_s, part: info.part.to_s, cid: info.cid }
    end

    # directories under download_dir, biggest first
    def downloaded_items
      root = File.expand_path(@opt[:download_dir].to_s, __dir__)
      return [] unless Dir.exist?(root)

      Dir.children(root).filter_map do |entry|
        path = File.join(root, entry)
        next unless File.directory?(path)

        files = Dir.glob(File.join(path, '**', '*')).select { |file| File.file?(file) }
        id, title = entry.split('-', 2)
        { id: id.to_s, title: title.to_s, path: path, files: files.size,
          size: files.sum { |file| File.size(file) } }
      end.sort_by { |item| -item[:size] }
    end

    # remove downloaded directories matching id; returns the matched names.
    # without force nothing is deleted, so callers can show a preview.
    def remove_downloaded(id, force: false)
      root = File.expand_path(@opt[:download_dir].to_s, __dir__)
      return [] unless Dir.exist?(root) && !id.to_s.empty?

      matches = Dir.children(root).select do |entry|
        File.directory?(File.join(root, entry)) &&
          (entry == id.to_s || entry.start_with?("#{id}-"))
      end
      matches.each { |entry| FileUtils.rm_rf(File.join(root, entry)) } if force
      matches
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

    def build_task(id, options = {})
      page_list = video_page_list(id)
      return nil if page_list.nil? || page_list.empty?

      info = get_video_info(id)
      return nil if info.nil?

      pages = page_slice(page_list, options[:start], options[:end], options[:page])
      qn = options[:qn] || @opt[:video_qn].to_s
      dir = "#{File.expand_path(@opt[:download_dir].to_s, __dir__)}/#{id}-#{safe_name(info.title)}/"
      segments = pages.flat_map do |page|
        get_video_url(id, page.cid, qn).to_a.map do |down_url|
          order = down_url[:order] < 10 ? "0#{down_url[:order]}" : down_url[:order]
          name = options[:rename].nil? ? "#{page.part}_#{order}.flv" : "#{options[:rename]}_#{order}.flv"
          { name: name, url: down_url[:url].to_s, prefix: page.part.to_s,
            order: "#{page.page}#{order}", status: 'pending', attempts: 0,
            total_size: down_url[:size].to_i }
        end
      end
      task = DownloadTask.new(id: "#{id}-#{Time.now.strftime('%Y%m%d%H%M%S')}", bvid: id,
                              title: info.title.to_s, qn: qn, dir: dir, segments: segments)
      store.save(task)
      task
    end

    def safe_name(name)
      name.to_s.gsub(%r{[/\\]}, '_').strip
    end

    def store
      @store ||= TaskStore.new(File.expand_path(@opt[:task_file].to_s, __dir__))
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
      File.write(@opt[:cookie].to_s, cookie.to_s) unless File.exist?(@opt[:cookie].to_s)
      if @opt[:enable_aria2]
        aria2_download(url, user_agent, referer, dir, filename)
      else
        wget_download(url, user_agent, referer, file_path)
      end
    end

    def wget_proxy
      command = ''
      command += " -e http_proxy=\"http://#{@opt[:proxy]}\"" unless @opt[:proxy].nil?
      command += " -e https_proxy=\"https://#{@opt[:proxy]}\"" unless @opt[:proxy].nil?
      command
    end

    def aria2_proxy
      command = ''
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
      command = "#{command} -c -d \"#{dir}\" -o \"#{filename}\" --max-tries=3 --file-allocation=none"

      Open3.popen3(command) do |_stdin, stdout, _stderr, _status|
        stdout.each_line do |line|
          puts line
        end
      end
    end
  end
end