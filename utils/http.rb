# frozen_string_literal: true

require 'net/http'
require 'nice_http'
require_relative 'base'
require_relative 'response_body'

# bilibili client http module
module BiliHttp
  def self.get_json(url)
    response = get(url)
    json_data(response)
  end

  def self.get(url)
    uri = URI(url)
    http = NiceHttp.new("http://#{uri.host}")
    response = http.get(uri.request_uri)
    response.data
  end

  def self.post_form_json(url, params)
    uri = URI(url)
    http = NiceHttp.new("http://#{uri.host}")
    request = {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      path: uri.request_uri,
      data: params
    }
    response = http.post(request)
    json_data(response.data)
  end

  def self.json_data(data)
    body = BiliHttp::ResponseBody.new(data.json.to_s)
    puts "body: #{body}"
    body.data
  end

  include Base
end
