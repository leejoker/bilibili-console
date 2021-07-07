# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'bilibili_console'
  s.version = '0.0.1'
  s.executables << 'bc'
  s.summary     = 'bilibili console'
  s.description = 'a console tool for bilibili'
  s.authors     = ['leejoker']
  s.email       = '1056650571@qq.com'
  s.files       = ['lib/bilibili_console.rb',
                   'lib/bilibili_console/login.rb',
                   'lib/bilibili_console/user_info.rb',
                   'lib/bilibili_console/http/http.rb',
                   'lib/bilibili_console/http/response_body.rb']
  s.homepage = 'https://github.com/leejoker/bilibili-console'
  s.license = 'MIT'
  s.required_ruby_version = ['>= 2.7']
end