# frozen_string_literal: true

require 'rake'
require 'rake/testtask'
require 'sequel'
require 'fileutils'

# Load application and environment configurations
require_relative 'require_app' # Assuming this file sets up your application environment

task :default do
  puts `rake -T`
end

# Testing tasks
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/*_spec.rb'
  t.warning = false
end

desc 'Run Google Vision API tests'
task :spec_google do
  sh 'ruby spec/google_vision_api_spec.rb'
end

desc 'Run OpenAI API tests'
task :spec_openai do
  sh 'ruby spec/openai_api_spec.rb'
end

task spec: %i[spec_google spec_openai]

desc 'Keep rerunning tests upon changes'
task :respec do
  sh "rerun -c 'rake spec' --ignore 'coverage/*'"
end

# Application tasks
desc 'Run web app'
task :run do
  sh 'bundle exec puma'
end

desc 'Keep rerunning web app upon changes'
task :rerun do
  sh "rerun -c --ignore 'coverage/*' -- bundle exec puma"
end

# Database tasks
namespace :db do
  task :config do
    require 'sequel'
    require_relative 'config/environment' # load config info
    require_relative 'spec/helpers/database_helper'

    def app = MealDecoder::App
  end

  desc 'Run migrations'
  task migrate: :config do
    Sequel.extension :migration
    puts "Migrating #{app.environment} database to latest"
    Sequel::Migrator.run(app.db, 'db/migrations')
  end

  desc 'Wipe records from all tables'
  task wipe: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    require_app(%w[models infrastructure])
    DatabaseHelper.wipe_database
  end

  desc 'Delete dev or test database file (set correct RACK_ENV)'
  task drop: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    FileUtils.rm(MealDecoder::App.config.DB_FILENAME)
    puts "Deleted #{MealDecoder::App.config.DB_FILENAME}"
  end
end

# Console task
desc 'Run application console'
task :console do
  sh 'pry -r ./load_all'
end

# VCR and quality control tasks (for static analysis and code quality checks)
namespace :vcr do
  desc 'Delete cassette fixtures'
  task :wipe do
    FileUtils.rm_rf('spec/fixtures/cassettes/*.yml')
    puts 'Cassettes deleted'
  end
end

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
    sh 'flog -m config app' # Update paths as needed for your application structure
  end
end
