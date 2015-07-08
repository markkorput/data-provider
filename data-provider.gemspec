GEM_NAME="data-provider"
PKG_VERSION='0.0.1'

Gem::Specification.new do |s|
  s.name = GEM_NAME
  s.version = PKG_VERSION
  s.files = `git ls-files`.split($/)
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.add_development_dependency 'rspec'

  s.author = "Mark van de Korput"
  s.email = "dr.theman@gmail.com"
  s.date = '2015-07-08'
  s.description = %q{A library of Ruby classes to help create consistent data interfaces}
  s.summary = %q{A library of Ruby classes to help create consistent data interfaces}
  s.homepage = %q{https://github.com/markkorput/data-provider}
  s.license = "MIT"
end
