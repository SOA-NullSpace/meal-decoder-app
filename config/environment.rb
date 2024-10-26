# frozen_string_literal: true

require 'figaro'
require 'roda'
require 'sequel'
require 'yaml'

module MealDecoder
  # Configuration for the App
  class App < Roda
    plugin :environments

    # Setup base configuration
    # CONFIG = YAML.safe_load_file(File.join(__dir__, 'secrets.yml'), aliases: true)
    # OPENAI_API_KEY = CONFIG['OPENAI_API_KEY']
    # GOOGLE_CLOUD_API_TOKEN = CONFIG['GOOGLE_CLOUD_API_TOKEN']

    # Environment variables setup using Figaro
    Figaro.application = Figaro::Application.new(
      environment: ENV['RACK_ENV'] || 'development',
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load

    def self.config = Figaro.env

    configure :development, :test do
      ENV['DATABASE_URL'] = "sqlite://#{config.DB_FILENAME}"
    end

    # Database Setup
    @db = Sequel.connect(ENV.fetch('DATABASE_URL'))
    def self.db = @db # rubocop:disable Style/TrivialAccessors

    # Load all application files
    # Dir.glob(File.join(__dir__, '../app/**/*.rb')).sort.each { |file| require file }
  end
end
