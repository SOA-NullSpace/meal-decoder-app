# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start

require 'yaml'
require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/rg'
require 'vcr'
require 'webmock'

require_relative '../require_app'
require_app

# Configuration for test run
CONFIG = YAML.safe_load_file('config/secrets.yml')['test']
OPENAI_API_KEY = MealDecoder::App.config.OPENAI_API_KEY
GOOGLE_CLOUD_API_TOKEN = MealDecoder::App.config.GOOGLE_CLOUD_API_TOKEN
