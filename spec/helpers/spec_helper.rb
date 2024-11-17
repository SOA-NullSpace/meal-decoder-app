# frozen_string_literal: true

require 'vcr'
require 'webmock'

module SpecHelper
  # Common test configuration for all types of tests
  CONFIG = YAML.safe_load_file('config/secrets.yml')['test']

  # Helper method to setup test state (if needed)
  def self.setup_test_state
    DatabaseHelper.wipe_database
  end

  # Helper method for test fixtures
  def self.load_fixture(filename)
    YAML.safe_load_file "spec/fixtures/#{filename}"
  end

  # Helper method for test data paths
  def self.test_data_path(filename)
    File.join(__dir__, '..', 'fixtures', filename)
  end
end
