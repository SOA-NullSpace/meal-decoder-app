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
      unless dish_name.match?(/\A[\p{L}\s]+\z/u)
        return { error: messages[:invalid_name] }
      end

      begin
        dish = Repository::For.klass(Entity::Dish).find_name(dish_name)

        if dish.nil? || dish.ingredients.empty?
          begin
            # Get dish from OpenAI API
            api_key = App.config.OPENAI_API_KEY
            api = Gateways::OpenAIAPI.new(api_key)
            mapper = Mappers::DishMapper.new(api)
            api_dish = mapper.find(dish_name)

            # Clean up old data if exists
            Repository::For.klass(Entity::Dish).delete(dish.id) if dish&.id

            # Create new dish
            dish = Repository::For.klass(Entity::Dish).create(api_dish)
          rescue StandardError => e
            puts "API ERROR: #{e.message}"
            return { error: messages[:api_error] }
          end
        end

        if dish&.ingredients&.any?
          # Add to search history
          routing.session[:searched_dishes] ||= []
          routing.session[:searched_dishes].insert(0, dish.name).uniq!
          return { success: messages[:success_created], dish: dish }
        else
          return { error: messages[:no_ingredients] }
        end
      rescue StandardError => e
        puts "DB ERROR: #{e.message}"
        return { error: messages[:db_error] }
      end
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
            Repository::For.klass(Entity::Dish).find_name(dish_name)
          end.compact

          # Update session with valid dishes only
          session[:searched_dishes] = dishes.map(&:name)

          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new(dishes)
          }
        rescue StandardError => e
          puts "DB ERROR: #{e.message}"
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
            dish = Repository::For.klass(Entity::Dish).find_name(dish_name)

            if dish
              # Ensure dish is in search history
              session[:searched_dishes].insert(0, dish.name).uniq!
              view 'dish', locals: {
                title_suffix: dish.name,
                dish: Views::Dish.new(dish)
              }
            else
              flash[:error] = MESSAGES[:dish_not_found]
              routing.redirect '/'
            end
          rescue StandardError => e
            puts "DISH DISPLAY ERROR: #{e.message}"
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
          rescue StandardError => e
            puts "VISION API ERROR: #{e.message}"
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
