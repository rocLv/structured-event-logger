require 'bundler/gem_tasks'
require 'rake/testtask'
 
Rake::TestTask.new(:test) do |t|
  t.test_files = Dir.glob('test/**/*_test.rb')
  t.libs << 'test'
end

task :default => :test
