# frozen_string_literal: true

require_relative 'require_app'
require_app

require './config/environment'
run MealDecoder::Application::App.freeze.app
