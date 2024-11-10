# frozen_string_literal: true

require 'figaro'
require 'roda'
require 'sequel'
require 'yaml'
require 'rack/session'

module MealDecoder
  # Configuration for the App
  class App < Roda
    # use Rack::Session::Cookie, secret: config.SESSION_SECRET
    plugin :environments
    env = ENV['RACK_ENV'] || 'development'
    # Environment variables setup using Figaro
    Figaro.application = Figaro::Application.new(
      environment: env,
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

    use Rack::Session::Cookie,
        secret: config.SESSION_SECRET,
        key: 'meal_decoder.session',
        expire_after: 2_592_000 # 30 days in seconds

    configure :production do
      # Use DATABASE_URL from environment
    end

    # Database Setup
    DB = Sequel.connect(ENV.fetch('DATABASE_URL'))
    def self.db = DB # Class accessor for database

    # Load all application files
    def self.setup_application!
      Sequel.extension :migration
      db.extension :freeze_datasets if env == 'production'

      # Run migrations if in development/test
      return unless %w[development test].include?(env)

      Sequel::Migrator.run(db, 'db/migrations') if db.tables.empty?
    end
  end
end
