require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubygems/package_task'

gemspec = eval(File.read('structured-event-logger.gemspec'))
Gem::PackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

desc "Build the gem and release it to rubygems.org"
task :release => :gem do
  sh "gem push pkg/structured-event-logger-#{gemspec.version}.gem"
end

Rake::TestTask.new(:test) do |t|
  t.test_files = Dir.glob('test/**/*_test.rb')
  t.libs << 'test'
end

task :default => :test
