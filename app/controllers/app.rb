# app/controllers/app.rb
# frozen_string_literal: true

require 'roda'
require 'slim'
require_relative '../models/gateways/openai_api'
require_relative '../models/mappers/dish_mapper'

module MealDecoder
  class App < Roda
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/view'

    # Correctly serve static files from the 'view/assets' folder
    plugin :public, root: File.join(__dir__, '../view/assets')
    plugin :static, ['/assets']

    route do |r|
      r.public # Serve static files like CSS and images

      r.root do
        view 'index', locals: { error: nil }
      end

      r.post 'fetch_dish' do
        dish_name = r.params['dish_name'].strip
        if dish_name.match?(/\A[\p{L}\s]+\z/u)
          api_key = MealDecoder::Configuration::OPENAI_API_KEY
          dish = MealDecoder::Mappers::DishMapper.new(MealDecoder::Gateways::OpenAIAPI.new(api_key)).find(dish_name)
          view 'display_dish', locals: { dish: }
        else
          view 'index', locals: { error: 'Invalid dish name. Please enter a valid name (letters and spaces only).' }
        end
      end
    end
  end
end
