# frozen_string_literal: true

# Copyright (c) 2021 leejoker
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'fileutils'
require 'json'
require 'time'

# download task queue (persisted, resumable, parallel workers)
module Bilibili
  # one download task with its segments
  class DownloadTask
    OPEN_STATUSES = %w[pending running paused failed canceling].freeze

    attr_reader :id, :bvid, :title, :qn, :dir, :segments, :created_at
    attr_accessor :status, :error, :updated_at

    def initialize(attrs = {})
      @id = attrs[:id].to_s
      @bvid = attrs[:bvid].to_s
      @title = attrs[:title].to_s
      @qn = attrs[:qn].to_s
      @dir = attrs[:dir].to_s
      @status = (attrs[:status].to_s.empty? ? 'pending' : attrs[:status].to_s)
      @error = attrs[:error].to_s
      @created_at = attrs[:created_at] || Time.now.to_i
      @updated_at = attrs[:updated_at] || @created_at
      @segments = Array(attrs[:segments]).map { |segment| normalize_segment(segment) }
    end

    def normalize_segment(segment)
      {
        name: segment[:name].to_s,
        url: segment[:url].to_s,
        prefix: segment[:prefix].to_s,
        order: segment[:order].to_s,
        status: (segment[:status].to_s.empty? ? 'pending' : segment[:status].to_s),
        attempts: segment[:attempts].to_i,
        file_path: segment[:file_path].to_s,
        size: segment[:size].to_i,
        total_size: segment[:total_size].to_i,
        error: segment[:error].to_s
      }
    end

    def open?
      OPEN_STATUSES.include?(@status)
    end

    def done?
      @status == 'done'
    end

    def total
      @segments.size
    end

    def done_count
      @segments.count { |segment| segment[:status] == 'done' }
    end

    def failed_count
      @segments.count { |segment| segment[:status] == 'failed' }
    end

    def pending_segments
      @segments.select { |segment| segment[:status] != 'done' }
    end

    def touch
      @updated_at = Time.now.to_i
    end

    def to_h
      {
        id: @id, bvid: @bvid, title: @title, qn: @qn, dir: @dir, status: @status,
        error: @error, created_at: @created_at, updated_at: @updated_at, segments: @segments
      }
    end
  end

  # locked json store for download tasks
  class TaskStore
    VERSION = 1

    def initialize(path)
      @path = path.to_s
      @mutex = Mutex.new
    end

    def all
      @mutex.synchronize { load_tasks }
    end

    def find(id)
      all.find { |task| task.id == id.to_s }
    end

    def find_open_by_bvid(bvid)
      all.select { |task| task.bvid == bvid.to_s && task.open? }.max_by(&:updated_at)
    end

    def save(task)
      @mutex.synchronize do
        tasks = load_tasks.reject { |item| item.id == task.id }
        tasks << task
        write(tasks)
      end
      task
    end

    def delete(id)
      @mutex.synchronize do
        tasks = load_tasks
        removed = tasks.find { |task| task.id == id.to_s }
        write(tasks.reject { |task| task.id == id.to_s }) if removed
        removed
      end
    end

    private

    def load_tasks
      return [] unless File.exist?(@path)

      data = JSON.parse(File.read(@path), symbolize_names: true)
      Array(data[:tasks]).map { |task| DownloadTask.new(task) }
    rescue JSON::ParserError
      []
    end

    def write(tasks)
      FileUtils.mkdir_p(File.dirname(@path))
      payload = { version: VERSION, tasks: tasks.map(&:to_h) }
      handle = open_handle
      begin
        flock = try_flock(handle)
        handle.seek(0)
        handle.truncate(0)
        handle.write(JSON.pretty_generate(payload))
        handle.flush
      ensure
        unlock(handle, flock)
        handle.close
      end
    end

    def open_handle
      File.exist?(@path) ? File.open(@path, 'r+') : File.open(@path, 'w')
    end

    def try_flock(handle)
      require 'fcntl'
      handle.flock(File::LOCK_EX)
      true
    rescue LoadError, SystemCallError
      false
    end

    def unlock(handle, locked)
      handle.flock(File::LOCK_UN) if locked
    rescue SystemCallError
      nil
    end
  end

  # runs a DownloadTask with a bounded worker pool
  class DownloadTaskRunner
    MAX_ATTEMPTS = 3

    def initialize(task, store, video, workers: 1)
      @task = task
      @store = store
      @video = video
      @workers = (workers || 1).to_i
      @workers = 1 if @workers < 1
      @workers = 8 if @workers > 8
      @task_mutex = Mutex.new
      @stop = false
    end

    def run
      update_status('running')
      runnable = @task.pending_segments
      dispatch(runnable) unless runnable.empty?
      finalize
      @task
    rescue StandardError => e
      $log&.error("task #{@task.id} failed: #{e.message}")
      @task.error = e.message
      update_status('failed')
      @task
    end

    private

    def dispatch(segments)
      queue = Queue.new
      segments.each { |segment| queue << segment }
      threads = Array.new([@workers, segments.size].min) { Thread.new { work_loop(queue) } }
      threads.each(&:join)
    end

    def work_loop(queue)
      loop do
        break if @stop || cancel_requested?

        segment = begin
          queue.pop(true)
        rescue ThreadError
          nil
        end
        break if segment.nil?

        download_segment(segment)
      end
    end

    def download_segment(segment)
      segment[:attempts] = segment[:attempts].to_i + 1
      segment[:status] = 'running'
      @task_mutex.synchronize { persist }
      relative = segment[:name]
      path = File.join(@task.dir, relative)
      FileUtils.mkdir_p(@task.dir)
      @video.send(:download, segment[:url], user_agent, referer, cookie,
                  "#{@task.dir}/", relative)
      raise "下载文件为空：#{path}" unless File.exist?(path) && File.size(path).positive?

      segment[:status] = 'done'
      segment[:file_path] = path
      segment[:size] = File.size(path)
      segment[:error] = ''
      $log&.info("segment done: #{relative} (#{segment[:size]} bytes)")
      puts "完成 #{relative} (#{segment[:size]} bytes)"
    rescue StandardError => e
      segment[:status] = 'failed'
      segment[:error] = e.message
      $log&.error("segment failed: #{relative} #{e.message}")
      puts "失败 #{relative}: #{e.message}"
    ensure
      @task_mutex.synchronize { persist }
    end

    def cancel_requested?
      fresh = @store.find(@task.id)
      return false if fresh.nil?

      if %w[canceling canceled].include?(fresh.status)
        @stop = true
        true
      else
        false
      end
    end

    def finalize
      merge_ready_groups
      if @task.segments.all? { |segment| segment[:status] == 'done' }
        update_status('done')
      elsif cancel_requested?
        update_status('canceled')
      elsif @task.failed_count.positive?
        update_status('failed')
      else
        update_status('paused')
      end
      @task
    end

    def merge_ready_groups
      @task.segments.group_by { |segment| segment[:prefix] }.each do |prefix, segments|
        next unless segments.all? { |segment| segment[:status] == 'done' }

        dest = File.join(@task.dir, "#{prefix}.flv")
        next if File.exist?(dest) && File.size(dest).positive?

        files = segments.map { |segment| segment[:file_path].to_s }.select { |file| File.exist?(file) }
        merge_files(files, dest)
      end
    rescue StandardError => e
      @task.error = e.message
      $log&.error("merge failed: #{e.message}")
      raise
    end

    def merge_files(files, dest)
      return if files.empty?

      if files.size == 1
        FileUtils.mv(files.first, dest, force: true)
        return
      end

      ffmpeg = path_lookup('ffmpeg')
      raise '未安装 ffmpeg，无法合并分片；安装后执行 bilic tasks <task-id> --retry' if ffmpeg.nil?

      list_path = "#{dest}.concat.txt"
      File.write(list_path, files.map { |file| "file '#{file}'" }.join("\n"))
      ok = system(ffmpeg, '-y', '-f', 'concat', '-safe', '0', '-i', list_path, '-c', 'copy', dest)
      File.delete(list_path) if File.exist?(list_path)
      raise 'ffmpeg 合并失败' unless ok && File.exist?(dest)
    end

    def update_status(status)
      @task_mutex.synchronize do
        @task.status = status
        persist
      end
      puts "任务 #{@task.id}: #{@task.status} (#{@task.done_count}/#{@task.total})"
    end

    # save while honouring a cancellation requested from another process;
    # "canceled" is decisive, "canceling" wins over an in-flight running state
    def persist
      fresh = @store.find(@task.id)
      if fresh
        if fresh.status == 'canceled' || @task.status == 'canceled'
          @task.status = 'canceled'
        elsif fresh.status == 'canceling'
          @task.status = 'canceling'
        end
      end
      @task.touch
      @store.save(@task)
    end

    def user_agent
      BiliHttp.headers ? BiliHttp.headers[:"User-Agent"].to_s : 'Mozilla/5.0'
    end

    def referer
      BiliHttp.headers ? BiliHttp.headers[:Referer].to_s : 'https://www.bilibili.com/'
    end

    def cookie
      @video.cookie_string
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