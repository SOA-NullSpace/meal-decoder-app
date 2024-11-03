# frozen_string_literal: true

require 'roda'
require 'slim'
require_relative '../infrastructure/meal_decoder/gateways/openai_api'
require_relative '../infrastructure/meal_decoder/gateways/google_vision_api'
require_relative '../infrastructure/meal_decoder/mappers/dish_mapper'
require_relative '../../config/environment'

module MealDecoder
  # Web App
  class App < Roda
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/view'
    plugin :public, root: File.join(__dir__, '../view/assets')
    plugin :static, ['/assets']
    plugin :flash
    plugin :all_verbs
    plugin :request_headers

    route do |request|
      request.public # Serve static files

      # GET /
      request.root do
        view 'index', locals: { error: nil }
      end

      # POST /fetch_dish
      request.post 'fetch_dish' do
        dish_name = request.params['dish_name'].strip

        if dish_name.match?(/\A[\p{L}\s]+\z/u)
          begin
            dish = Repository::For.klass(Entity::Dish).find_name(dish_name)

            if dish.nil? || dish.ingredients.empty?
              api_key = Figaro.env.openai_api_key
              api = Gateways::OpenAIAPI.new(api_key)
              mapper = Mappers::DishMapper.new(api)
              api_dish = mapper.find(dish_name)

              if dish&.id && dish.ingredients.empty?
                Repository::For.klass(Entity::Dish).delete(dish.id)
              end

              dish = Repository::For.klass(Entity::Dish).create(api_dish)
            end

            if dish && dish.ingredients.any?
              request.redirect "/display_dish?name=#{CGI.escape(dish_name)}"
            else
              request.redirect "/?error=#{CGI.escape('No ingredients found for this dish.')}"
            end
          rescue StandardError => error
            request.redirect "/?error=#{CGI.escape(error.message)}"
          end
        else
          request.redirect "/?error=#{CGI.escape('Invalid dish name. Please enter a valid name (letters and spaces only).')}"
        end
      end

      # GET /display_dish
      request.get 'display_dish' do
        dish_name = request.params['name']
        if dish_name
          dish = Repository::For.klass(Entity::Dish).find_name(dish_name)
          if dish
            view 'display_dish', locals: { dish: dish }
          else
            request.redirect "/?error=#{CGI.escape('Dish not found.')}"
          end
        else
          request.redirect '/'
        end
      end

      # POST /detect_text
      request.post 'detect_text' do
        file = request.params['image_file'][:tempfile]
        file_path = file.path

        if file
          api_key = Figaro.env.google_cloud_api_token
          google_vision_api = Gateways::GoogleVisionAPI.new(api_key)
          text_result = google_vision_api.detect_text(file_path)

          view 'display_text', locals: { text: text_result }
        else
          request.redirect "/?error=#{CGI.escape('No file uploaded. Please upload an image file.')}"
        end
      end
    end
  end
end