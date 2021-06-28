# frozen_string_literal: true

require 'net/http'
require_relative 'base'
require_relative 'response_body'

# bilibili client http module
module BiliHttp
  def self.get_json(url)
    response = Net::HTTP.get_response(URI(url))
    json_data(response)
  end

  def self.get(url)
    response = Net::HTTP.get_response(URI(url))
    response.body
  end

  def self.post_form_json(url, params)
    response = Net::HTTP.post_form(URI(url), params)
    json_data(response)
  end

  def self.json_data(response)
    header = BiliHttp::ResponseHeader.new(response.headers)
    body = BiliHttp::ResponseBody.new(response.body)
    puts "headers: #{header}"
    puts "body: #{body}"
    header.save_cookie
    body.data
  end

  include Base
end
