# frozen_string_literal: true

require 'roda'
require 'slim'
require 'rack'
require_relative '../infrastructure/meal_decoder/gateways/openai_api'
require_relative '../infrastructure/meal_decoder/gateways/google_vision_api'
require_relative '../infrastructure/meal_decoder/mappers/dish_mapper'
require_relative '../../config/environment'
require_relative '../presentation/view_objects/init'

module MealDecoder
  # Web App
  class App < Roda
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/assets'
    plugin :static, ['/assets']
    plugin :flash
    plugin :all_verbs
    plugin :request_headers
    plugin :common_logger, $stderr
    plugin :halt

    use Rack::MethodOverride
    use Rack::Session::Cookie,
        secret: config.SESSION_SECRET,
        key: 'meal_decoder.session',
        expire_after: 2_592_000 # 30 days in seconds

    MESSAGES = {
      no_dishes: 'Search for a dish to get started',
      dish_not_found: 'Could not find that dish',
      api_error: 'Having trouble accessing the API',
      invalid_name: 'Invalid dish name. Please enter a valid name (letters and spaces only).',
      no_ingredients: 'No ingredients found for this dish.',
      db_error: 'Having trouble accessing the database',
      api_dish_error: 'Could not fetch dish information',
      success_created: 'Successfully added new dish!',
      success_deleted: 'Dish removed from history',
      text_detection_error: 'Error processing image text',
      no_file: 'No file uploaded. Please upload an image file.'
    }.freeze

    # Helper method to process dish and update search history
    def self.process_dish_request(routing, dish_name, messages)
      return handle_invalid_dish_name(messages) unless valid_dish_name?(dish_name)

      process_valid_dish_request(routing, dish_name, messages)
    rescue StandardError => error
      handle_db_error(error, messages)
    end

    def self.process_valid_dish_request(routing, dish_name, messages)
      dish = find_or_create_dish(dish_name)
      return handle_api_error_response(messages) unless dish

      process_dish_with_ingredients(routing, dish, messages)
    end

    def self.process_dish_with_ingredients(routing, dish, messages)
      if dish.ingredients.any?
        add_to_search_history(routing, dish.name)
        { success: messages[:success_created], dish: dish }
      else
        handle_no_ingredients(messages)
      end
    end

    def self.handle_dish_response(dish, messages)
      if dish.ingredients.any?
        { success: messages[:success_created], dish: dish }
      else
        handle_no_ingredients(messages)
      end
    end

    def self.handle_no_ingredients(messages)
      { error: messages[:no_ingredients] }
    end

    def self.handle_invalid_dish_name(messages)
      { error: messages[:invalid_name] }
    end

    def self.handle_api_error_response(messages)
      { error: messages[:api_error] }
    end

    def self.valid_dish_name?(dish_name)
      dish_name.match?(/\A[\p{L}\s]+\z/u)
    end

    def self.find_or_create_dish(dish_name)
      dish = dish_from_repository(dish_name)
      return dish if dish && dish.ingredients.any?

      create_dish_from_api(dish_name)
    end

    def self.dish_from_repository(dish_name)
      Repository::For.klass(Entity::Dish).find_name(dish_name)
    end

    def self.create_dish_from_api(dish_name)
      api_key = App.config.OPENAI_API_KEY
      api_dish = fetch_dish_from_api(dish_name, api_key)
      return unless api_dish

      delete_existing_dish(dish_name)
      Repository::For.klass(Entity::Dish).create(api_dish)
    end

    def self.fetch_dish_from_api(dish_name, api_key)
      api = Gateways::OpenAIAPI.new(api_key)
      mapper = Mappers::DishMapper.new(api)
      mapper.find(dish_name)
    rescue StandardError => error
      handle_api_error(error)
    end

    def self.handle_api_error(error)
      puts "API ERROR: #{error.message}"
      nil
    end

    def self.delete_existing_dish(dish_name)
      dish = dish_from_repository(dish_name)
      Repository::For.klass(Entity::Dish).delete(dish.id) if dish&.id
    end

    def self.add_to_search_history(routing, dish_name)
      searched_dishes = routing.session[:searched_dishes] ||= []
      searched_dishes.insert(0, dish_name).uniq!
    end

    def self.handle_db_error(error, messages)
      puts "DB ERROR: #{error.message}"
      { error: messages[:db_error] }
    end

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public

      # GET /
      routing.root do
        # Initialize or retrieve session
        session[:searched_dishes] ||= []

        begin
          # Load dishes from session history
          dishes = session[:searched_dishes].map do |dish_name|
            self.class.dish_from_repository(dish_name)
          end.compact

          # Update session with valid dishes only
          session[:searched_dishes] = dishes.map(&:name)

          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new(dishes)
          }
        rescue StandardError => db_error
          puts "DB ERROR: #{db_error.message}"
          flash.now[:error] = MESSAGES[:db_error]
          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new([])
          }
        end
      end

      routing.on 'fetch_dish' do
        # POST /fetch_dish
        routing.post do
          dish_name = routing.params['dish_name'].strip
          result = self.class.process_dish_request(routing, dish_name, MESSAGES)

          if result[:error]
            flash[:error] = result[:error]
            routing.redirect '/'
          else
            flash[:success] = result[:success]
            routing.redirect "/display_dish?name=#{CGI.escape(dish_name)}"
          end
        end
      end

      routing.on 'display_dish' do
        # GET /display_dish
        routing.get do
          dish_name = routing.params['name']

          unless dish_name
            flash[:error] = MESSAGES[:dish_not_found]
            routing.redirect '/'
          end

          begin
            dish = self.class.dish_from_repository(dish_name)

            if dish
              # Ensure dish is in search history
              self.class.add_to_search_history(routing, dish.name)
              view 'dish', locals: {
                title_suffix: dish.name,
                dish: Views::Dish.new(dish)
              }
            else
              flash[:error] = MESSAGES[:dish_not_found]
              routing.redirect '/'
            end
          rescue StandardError => db_error
            puts "DISH DISPLAY ERROR: #{db_error.message}"
            flash[:error] = MESSAGES[:db_error]
            routing.redirect '/'
          end
        end
      end

      routing.on 'detect_text' do
        # POST /detect_text
        routing.post do
          unless routing.params['image_file']
            flash[:error] = MESSAGES[:no_file]
            routing.redirect '/'
          end

          begin
            file = routing.params['image_file'][:tempfile]
            api_key = App.config.GOOGLE_CLOUD_API_TOKEN
            google_vision_api = Gateways::GoogleVisionAPI.new(api_key)
            text_result = google_vision_api.detect_text(file.path)

            view 'display_text', locals: {
              title_suffix: 'Text Detection',
              text: Views::TextDetection.new(text_result)
            }
          rescue StandardError => vision_error
            puts "VISION API ERROR: #{vision_error.message}"
            flash[:error] = MESSAGES[:text_detection_error]
            routing.redirect '/'
          end
        end
      end

      # DELETE /dish/{dish_name}
      routing.on 'dish', String do |dish_name|
        routing.delete do
          # Remove from search history
          session[:searched_dishes].delete(dish_name)
          flash[:success] = MESSAGES[:success_deleted]
          routing.redirect '/'
        end
      end
    end
  end
end
