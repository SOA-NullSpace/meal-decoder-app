# app/controllers/app.rb
# frozen_string_literal: true

require 'roda'
require 'slim'
require_relative '../infrastructure/meal_decoder/gateways/openai_api'
require_relative '../infrastructure/meal_decoder/gateways/google_vision_api'
require_relative '../infrastructure/meal_decoder/mappers/dish_mapper'
require_relative '../../config/environment'

module MealDecoder
  class App < Roda
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/view'

    plugin :public, root: File.join(__dir__, '../view/assets')
    plugin :static, ['/assets']

    route do |request|
      request.public # Serve static files

      request.root do
        view 'index', locals: { error: nil }
      end

      request.post 'fetch_dish' do
        dish_name = request.params['dish_name'].strip

        if dish_name.match?(/\A[\p{L}\s]+\z/u)
          api_key = Figaro.env.openai_api_key
          dish = MealDecoder::Mappers::DishMapper.new(
            MealDecoder::Gateways::OpenAIAPI.new(api_key)
          ).find(dish_name)

          view 'display_dish', locals: { dish: }
        else
          view 'index', locals: { error: 'Invalid dish name. Please enter a valid name (letters and spaces only).' }
        end
      end

      request.post 'detect_text' do
        file = request.params['image_file'][:tempfile]
        file_path = file.path

        if file
          api_key = Figaro.env.google_cloud_api_token
          google_vision_api = MealDecoder::Gateways::GoogleVisionAPI.new(api_key)
          text_result = google_vision_api.detect_text(file_path)

          view 'display_text', locals: { text: text_result }
        else
          view 'index', locals: { error: 'No file uploaded. Please upload an image file.' }
        end
      end
    end
  end
end
