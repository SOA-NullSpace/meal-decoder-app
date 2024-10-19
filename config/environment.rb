# frozen_string_literal: true

require 'bundler'
require 'yaml'
Bundler.require(:default)

# Setup the base configuration
module MealDecoder
  class Configuration
    CONFIG = YAML.safe_load_file(File.join(__dir__, 'secrets.yml'), aliases: true)
    OPENAI_API_KEY = CONFIG['OPENAI_API_KEY']
    GOOGLE_CLOUD_API_TOKEN = CONFIG['GOOGLE_CLOUD_API_TOKEN']
  end
end

# Load all application files
Dir.glob(File.join(__dir__, '../app/**/*.rb')).sort.each { |file| require file }
