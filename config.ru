# frozen_string_literal: true

require 'faye'
require_relative 'require_app'
require_app

require './config/environment'

# Initialize the app before using Faye
app = MealDecoder::App

use Faye::RackAdapter, mount: '/faye', timeout: 25
run app.app
