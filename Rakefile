# frozen_string_literal: true

require 'rake'
require 'rake/testtask'
require 'sequel'
require 'fileutils'

# Load application and environment configurations
require_relative 'require_app'

# Helper module for database tasks
module DbHelper
  module_function

  def app
    require_relative 'config/environment'
    require_relative 'spec/helpers/database_helper'
    MealDecoder::App
  end
end

task :default do
  puts `rake -T`
end

# Testing tasks
desc 'Run all tests'
Rake::TestTask.new(:spec) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/**/*_spec.rb'
  t.warning = false
end

desc 'Run integration layer tests'
Rake::TestTask.new(:spec_layers) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/integration/layers/*_spec.rb'
  t.warning = false
end

desc 'Run integration service tests'
Rake::TestTask.new(:spec_services) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/integration/services/*_spec.rb'
  t.warning = false
end

desc 'Run unit tests'
Rake::TestTask.new(:spec_unit) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/unit/**/*_spec.rb'
  t.warning = false
end

# Run all specs
task spec: %i[spec_unit spec_layers spec_services]

desc 'Keep rerunning tests upon changes'
task :respec do
  sh "rerun -c 'rake spec' --ignore 'coverage/*'"
end

# Application tasks
desc 'Run web app'
task :run do
  sh 'bundle exec puma -p 3000'
end

desc 'Keep rerunning web app upon changes'
task :rerun do
  sh "rerun -c --ignore 'coverage/*' -- bundle exec puma"
end

# Rakefile

namespace :cache do
  task :config do # rubocop:disable Rake/Desc
    require_relative 'config/environment'
    require_relative 'app/infrastructure/cache/redis_cache'
    @api = MealDecoder::App
  end

  namespace :list do
    desc 'Lists development cache'
    task :dev do
      puts 'Lists development cache'
      list = `ls _cache/rack/meta`
      puts 'No local cache found' if list.empty?
      puts list
    end

    desc 'Lists production cache'
    task :production => :config do
      puts 'Finding production cache'
      keys = MealDecoder::Cache::Client.new(@api.config).keys
      puts 'No keys found' if keys.none?
      keys.each { |key| puts "Key: #{key}" }
    end
  end

  namespace :wipe do
    desc 'Delete development cache'
    task :dev do
      puts 'Deleting development cache'
      sh 'rm -rf _cache/*'
    end

    desc 'Delete production cache'
    task :production => :config do
      print 'Are you sure you wish to wipe the production cache? (y/n) '
      if $stdin.gets.chomp.downcase == 'y'
        puts 'Deleting production cache'
        wiped = MealDecoder::Cache::Client.new(@api.config).wipe
        wiped.each { |key| puts "Wiped: #{key}" }
      end
    end
  end
end

# Database tasks
namespace :db do
  desc 'Generates a 64 by secret for Rack::Session'
  task :new_session_secret do
    require 'base64'
    require 'SecureRandom'
    secret = SecureRandom.random_bytes(64).then { Base64.urlsafe_encode64(_1) }
    puts "SESSION_SECRET: #{secret}"
  end

  desc 'Run database migrations'
  task :migrate do
    require_relative 'config/environment'
    Sequel.extension :migration

    environment = ENV['RACK_ENV'] || 'development'
    puts "Migrating #{environment} database"

    Sequel::Migrator.run(MealDecoder::App.db, 'db/migrations')
  end

  desc 'Delete dev/test database file'
  task :drop do
    require_relative 'config/environment'

    if MealDecoder::App.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    FileUtils.rm(File.expand_path("db/local/#{MealDecoder::App.environment}.db"))
    puts "Deleted #{MealDecoder::App.environment} database"
  end

  desc 'Delete and migrate again'
  task reset: %i[drop migrate]
end

# Console task
desc 'Run application console'
task :console do
  sh 'pry -r ./load_all'
end

# VCR tasks
namespace :vcr do
  desc 'Delete cassette fixtures'
  task :wipe do
    FileUtils.rm_rf('spec/fixtures/cassettes/*.yml')
    puts 'Cassettes deleted'
  end
end

# Quality control tasks
namespace :quality do
  desc 'Run all static-analysis quality checks'
  task all: %i[rubocop reek flog]

  desc 'Code style linter'
  task :rubocop do
    sh 'rubocop'
  end

  desc 'Code smell detector'
  task :reek do
    sh 'reek'
  end

  desc 'Complexity analysis'
  task :flog do
    sh 'flog -m config app'
  end
end
