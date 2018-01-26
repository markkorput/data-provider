Gem::Specification.new do |s|
  s.name = "data-provider-fuga"
  s.version = '0.2.4'
  s.files = `git ls-files`.split($/)
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rake', '~> 10.1'
  s.add_development_dependency 'rspec', '~> 3.3'

  s.author = "Mark van de Korput"
  s.email = "dr.theman@gmail.com"
  s.date = '2015-08-27'
  s.description = %q{A library of Ruby classes to help create consistent data interfaces}
  s.summary = %q{A library of Ruby classes to help create consistent data interfaces}
  s.homepage = %q{https://github.com/markkorput/data-provider}
  s.license = "MIT"
end
