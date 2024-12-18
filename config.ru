# frozen_string_literal: true

require 'faye'
require_relative 'require_app'
require_app

require './config/environment'

# Initialize the app before using Faye
app = MealDecoder::App
# Only freeze in production
app = app.freeze if ENV['RACK_ENV'] == 'production'

use Faye::RackAdapter, mount: '/faye', timeout: 25
run app.app
