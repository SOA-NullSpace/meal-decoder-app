require 'simplecov'
SimpleCov.start

require 'yaml'
require 'minitest/autorun'
require 'minitest/rg'
require 'vcr'
require 'webmock'

require_relative '../lib/google_vision_api'

CONFIG = YAML.safe_load(File.read('config/secrets.yml'))
GOOGLE_CLOUD_API_TOKEN = CONFIG['GOOGLE_CLOUD_API_TOKEN']

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('<GOOGLE_CLOUD_API_TOKEN>') { GOOGLE_CLOUD_API_TOKEN }
end
