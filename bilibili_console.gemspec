require_relative 'lib/bilibili_console/version'

Gem::Specification.new do |s|
  s.name = 'bilibili_console'
  s.version = Bilibili::VERSION
  s.bindir = 'bin'
  s.executables = %w[bilic]
  s.summary = 'bilibili console'
  s.description = 'a console tool for bilibili'
  s.authors = ['leejoker']
  s.email = '1056650571@qq.com'
  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  s.extra_rdoc_files = %w[README.md LICENSE]
  s.homepage = 'https://github.com/leejoker/bilibili-console'
  s.license = 'MIT'
  s.required_ruby_version = ['>= 2.5']
  s.add_dependency 'socksify', '~> 1.7.1'
  s.add_dependency 'rqrcode', '~> 2.0'
  s.add_dependency 'thor', '~> 1.2.1'
  s.add_dependency 'sqlite3', '~> 1.6.0'
  s.add_dependency 'nokogiri', '~> 1.14.0'
  s.add_dependency 'rubyzip', '~> 2.3.2'
end
