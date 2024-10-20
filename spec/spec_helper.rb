require 'simplecov'
SimpleCov.start

require 'yaml'
require 'minitest/autorun'
require 'minitest/rg'
require 'vcr'
require 'webmock'

require_relative '../meal_decoder'

CONFIG = YAML.safe_load_file('config/secrets.yml')
GOOGLE_CLOUD_API_TOKEN = CONFIG['GOOGLE_CLOUD_API_TOKEN']
OPENAI_API_KEY = CONFIG['OPENAI_API_KEY']

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('<GOOGLE_CLOUD_API_TOKEN>') { GOOGLE_CLOUD_API_TOKEN }
  c.filter_sensitive_data('<OPENAI_API_KEY>') { OPENAI_API_KEY }
  c.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri body]
  }
end
