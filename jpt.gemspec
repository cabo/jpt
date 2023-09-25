Gem::Specification.new do |s|
  s.name = "jpt"
  s.version = "0.1.3"
  s.summary = "JSONPath tools"
  s.description = %q{jpt implements converters and miscellaneous tools for JSONPath}
  s.author = "Carsten Bormann"
  s.email = "cabo@tzi.org"
  s.license = "MIT"
  s.homepage = "http://github.com/cabo/jpt"
  s.files = Dir['lib/**/*.rb'] + %w(jpt.gemspec) + Dir['data/*'] + Dir['bin/**/*.rb']
  s.executables = Dir['bin/*'].map {|x| File.basename(x)}
  s.required_ruby_version = '>= 3.0'

  s.require_paths = ["lib"]

  s.add_development_dependency 'bundler', '~>1'
  s.add_dependency 'treetop', '~>1'
#  s.add_dependency 'json'
  s.add_dependency 'neatjson', '~>0.10'
end
