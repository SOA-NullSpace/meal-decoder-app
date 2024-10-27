# frozen_string_literal: true

source 'https://rubygems.org'

gem 'ostruct', '0.6.0'

# gem "rails"
gem 'pry'
gem 'rake', '13.2'

gem 'dry-struct', '1.6'
gem 'dry-types', '1.7'

# Networking
gem 'http', '5.2'

# Web Application
gem 'logger', '1.6'
gem 'puma', '6.4'
gem 'roda', '3.85'
gem 'slim', '5.2'

gem 'figaro'

# Database
gem 'hirb'
# gem 'hirb-unicode' # incompatible with new rubocop
gem 'sequel', '5.85'

group :development, :test do
  gem 'sqlite3', '~> 1.0'
end

# Testing
group :test do
  gem 'minitest', '5.25'
  gem 'minitest-rg', '5.3'
  gem 'simplecov', '0.22.0'
  gem 'vcr', '6.3'
  gem 'webmock', '3.24'
end

# Development
group :development do
  gem 'flog'
  gem 'reek'
  gem 'rerun'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
end
