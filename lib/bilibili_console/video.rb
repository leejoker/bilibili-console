require_relative 'http/http'
require 'down'
require 'ruby-progressbar'

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

      url = "http://api.bilibili.com/x/player/pagelist?bvid=#{bv_id}"
      datas = get_jsona(url)
      return nil if datas.nil?

      datas.map do |d|
        Bilibili::PageInfo.new(d)
      end
    end

    def get_video_url(bv_id, cid, video_qn = '720')
      qn = BilibiliBase.video_qn[video_qn]
      url = "http://api.bilibili.com/x/player/playurl?bvid=#{bv_id}&cid=#{cid}&qn=#{qn}&fnval=0&fnver=0&fourk=1"
      data = get_jsona(url)
      data[:durl]
    end

    def video_url_list(bv_id, video_qn = '720')
      result = []
      page_list = video_page_list(bv_id)
      return nil if page_list.nil?

      page_list.each do |page|
        get_video_url(bv_id, page.cid, video_qn).each do |durl|
          order = durl[:order] < 10 ? "0#{durl[:order]}" : durl[:order]
          result << { 'name': "#{page.part}_#{order}.flv", 'url': durl[:url].to_s }
        end
      end
      result
    end

    def download_video_by_bv(bv_id, video_qn = '720')
      urls = video_url_list(bv_id, video_qn)
      return nil if urls.empty?

      download_path = "#{Bilibili::OPTIONS['download_path']}/#{bv_id}/"
      urls.each do |durl|
        download_file(durl['url'], "#{download_path}#{durl['name']}")
      end
    end

    private

    def download_file(url, dest)
      progressbar = ProgressBar.create
      total_size = 0
      Down::NetHttp.download(url['url'],
                             destination: dest,
                             headers: BiliHttp.headers,
                             content_length_proc: proc { |size|
                                                    total_size = size
                                                  },
                             progress_proc: proc { |cursize|
                                              progressbar.progress = cursize.to_f / total_size.to_f * 100.0
                                            })
    end
  end
end
