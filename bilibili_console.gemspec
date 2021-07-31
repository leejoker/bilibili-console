Gem::Specification.new do |s|
  s.name = 'bilibili_console'
  s.version = '0.0.1'
  s.executables << 'bili-console'
  s.summary     = 'bilibili console'
  s.description = 'a console tool for bilibili'
  s.authors     = ['leejoker']
  s.email       = '1056650571@qq.com'
  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  s.extra_rdoc_files = ['README.md', 'LICENSE']
  s.homepage = 'https://github.com/leejoker/bilibili-console'
  s.license = 'MIT'
  s.required_ruby_version = ['>= 2.7']
  s.add_dependency 'down', '~> 5.0'
  s.add_dependency 'nice_http', '~> 1.8.9'
  s.add_dependency 'rqrcode', '~> 2.0'
  s.add_dependency 'ruby-progressbar', '~> 1.11.0'
  s.add_dependency 'thor', '~> 1.1.0'
end
