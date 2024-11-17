# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'minitest/rg'
require 'yaml'
require 'vcr'
require 'webmock'
require 'sequel'

require_relative 'helpers/vcr_helper'
require_relative 'helpers/database_helper'
require_relative '../require_app'
require_app

module MiniTestSetup
  def setup
    VcrHelper.setup_vcr
    DatabaseHelper.wipe_database
  end

  def teardown
    VcrHelper.eject_vcr
  end
end

CONFIG = YAML.safe_load_file('config/secrets.yml')['test']
OPENAI_API_KEY = MealDecoder::App.config.OPENAI_API_KEY
GOOGLE_CLOUD_API_TOKEN = MealDecoder::App.config.GOOGLE_CLOUD_API_TOKEN

def app = MealDecoder::App
