# frozen_string_literal: true

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

begin
  require 'reek/rake/task'

  desc 'Run code smell detection'
  Reek::Rake::Task.new(:reek) do |t|
    t.source_files = 'lib/**/*.rb'
    t.config_file = '.reek.yml'
    t.fail_on_error = false
  end
rescue LoadError
  desc 'Run code smell detection (Not available)'
  task :reek do
    warn 'Reek is not available. Add it to your Gemfile to use this task.'
  end
end

desc 'Run all quality checks'
task quality: %i[rubocop reek test_with_coverage]

task default: :quality
