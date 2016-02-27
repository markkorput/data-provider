require 'rdoc/task'
require "rspec/core/rake_task"

task :default => :rspec do; end

desc "Run all specs"
RSpec::Core::RakeTask.new('rspec') do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

# Rake::RDocTask.new do |rd|
#   rd.main = "README.rdoc"
#   rd.rdoc_dir = "doc/site/api"
#   rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
# end
