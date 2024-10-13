require 'rake/testtask'
require 'rubocop/rake_task'

desc 'Run tests'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['spec/**/*_spec.rb']
  t.warning = false
end

desc 'Run rubocop'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

desc 'Run tests with coverage'
task :test_with_coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['test'].execute
end

desc 'Run all quality checks'
task quality: %i[rubocop test_with_coverage]

task default: :quality
