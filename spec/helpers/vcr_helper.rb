# frozen_string_literal: true

require 'vcr'
require 'webmock'

# Setting up VCR for testing API calls
module VcrHelper
  CASSETTES_FOLDER = 'spec/fixtures/cassettes'
  OPENAI_CASSETTE = 'openai_api'
  VISION_CASSETTE = 'google_vision_api'

  def self.setup_vcr
    VCR.configure do |con|
      con.cassette_library_dir = CASSETTES_FOLDER
      con.hook_into :webmock
    end
  end

  def self.configure_vcr_for_apis(config)
    VCR.configure do |con|
      con.filter_sensitive_data('<OPENAI_API_KEY>') { config['OPENAI_API_KEY'] }
      con.filter_sensitive_data('<GOOGLE_CLOUD_API_TOKEN>') { config['GOOGLE_CLOUD_API_TOKEN'] }
    end
  end

  def self.setup_api_fixtures
    VCR.insert_cassette(
      OPENAI_CASSETTE,
      record: :new_episodes,
      match_requests_on: %i[method uri headers]
    )
  end

  def self.eject_vcr
    VCR.eject_cassette
  end
end
