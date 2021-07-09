# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)

require 'bilibili_console'
require 'json'

RSpec.describe BilibiliConsole do
  describe '#login_user_info' do
    it 'returns nil for login_user_info' do
      bc = BilibiliConsole.new
      user = bc.login_user_info
      puts user.to_json
      expect(user).to nil?
    end
  end
end
