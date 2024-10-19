# frozen_string_literal: true

# config.ru

require_relative 'require_app'
require_app

require './config/environment'
run MealDecoder::App.freeze.app
