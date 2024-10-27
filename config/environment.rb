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
      require 'pry'
      # Make sure the db directory exists
      db_path = File.expand_path("db/local/#{environment}.db")
      FileUtils.mkdir_p(File.dirname(db_path))
      ENV['DATABASE_URL'] = "sqlite://#{db_path}"
    end

    configure :production do
      # Use DATABASE_URL from environment
    end

    # Database Setup
    DB = Sequel.connect(ENV.fetch('DATABASE_URL'))
    def self.db = DB # Class accessor for database

    # Load all application files
    def self.setup_application!
      Sequel.extension :migration
      db.extension :freeze_datasets if ENV['RACK_ENV'] == 'production'

      # Run migrations if in development/test
      if %w[development test].include?(ENV['RACK_ENV'])
        Sequel::Migrator.run(db, 'db/migrations') if db.tables.empty?
      end
    end
  end
end
