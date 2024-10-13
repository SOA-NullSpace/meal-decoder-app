require 'simplecov'
SimpleCov.start

require 'yaml'
require 'minitest/autorun'
require 'minitest/rg'
require 'vcr'
require 'webmock'

require_relative '../lib/google_vision_api'
require_relative '../lib/meal_decoder'

CONFIG = YAML.safe_load(File.read('config/secrets.yml'))
GOOGLE_CLOUD_API_TOKEN = CONFIG['GOOGLE_CLOUD_API_TOKEN']
OPENAI_API_KEY = CONFIG['OPENAI_API_KEY']

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('<GOOGLE_CLOUD_API_TOKEN>') { GOOGLE_CLOUD_API_TOKEN }
  c.filter_sensitive_data('<OPENAI_API_KEY>') { OPENAI_API_KEY }
end
