# # frozen_string_literal: true

# require 'roda'
# require 'slim'
# require_relative '../infrastructure/meal_decoder/gateways/openai_api'
# require_relative '../infrastructure/meal_decoder/gateways/google_vision_api'
# require_relative '../infrastructure/meal_decoder/mappers/dish_mapper'
# require_relative '../../config/environment'

# module MealDecoder
#   # Web App
#   class App < Roda
#     plugin :environments
#     plugin :render, engine: 'slim', views: 'app/view'
#     plugin :public, root: File.join(__dir__, '../view/assets')
#     plugin :static, ['/assets']
#     plugin :flash
#     plugin :all_verbs
#     plugin :request_headers
#     plugin :common_logger, $stderr

#     MESSAGES = {
#       no_dishes: 'Search for a dish to get started',
#       dish_not_found: 'Could not find that dish',
#       api_error: 'Having trouble accessing the API',
#       invalid_name: 'Invalid dish name. Please enter a valid name (letters and spaces only).',
#       no_ingredients: 'No ingredients found for this dish.'
#     }.freeze

#     route do |request|
#       request.public # Serve static files

#       # GET /
#       request.root do
#         # Initialize session history if not exists
#         session[:searched_dishes] ||= []

#         view 'index', locals: {
#           error: nil,
#           searched_dishes: session[:searched_dishes]
#         }
#       end

#       # POST /fetch_dish
#       request.post 'fetch_dish' do
#         dish_name = request.params['dish_name'].strip

#         if dish_name.match?(/\A[\p{L}\s]+\z/u)
#           begin
#             dish = Repository::For.klass(Entity::Dish).find_name(dish_name)

#             if dish.nil? || dish.ingredients.empty?
#               api_key = Figaro.env.openai_api_key
#               api = Gateways::OpenAIAPI.new(api_key)
#               mapper = Mappers::DishMapper.new(api)
#               api_dish = mapper.find(dish_name)

#               Repository::For.klass(Entity::Dish).delete(dish.id) if dish&.id && dish.ingredients.empty?

#               dish = Repository::For.klass(Entity::Dish).create(api_dish)
#             end

#             if dish && dish.ingredients.any?
#               # Add to session history
#               session[:searched_dishes].insert(0, dish_name).uniq!
#               request.redirect "/display_dish?name=#{CGI.escape(dish_name)}"
#             else
#               request.redirect "/?error=#{CGI.escape(MESSAGES[:no_ingredients])}"
#             end
#           rescue StandardError => e
#             request.redirect "/?error=#{CGI.escape(e.message)}"
#           end
#         else
#           request.redirect "/?error=#{CGI.escape(MESSAGES[:invalid_name])}"
#         end
#       end

#       # GET /display_dish
#       request.get 'display_dish' do
#         dish_name = request.params['name']
#         if dish_name
#           dish = Repository::For.klass(Entity::Dish).find_name(dish_name)
#           if dish
#             view 'display_dish', locals: {
#               dish:,
#               searched_dishes: session[:searched_dishes] || []
#             }
#           else
#             request.redirect "/?error=#{CGI.escape(MESSAGES[:dish_not_found])}"
#           end
#         else
#           request.redirect '/'
#         end
#       end

#       # POST /detect_text
#       request.post 'detect_text' do
#         file = request.params['image_file'][:tempfile]
#         file_path = file.path

#         if file
#           api_key = Figaro.env.google_cloud_api_token
#           google_vision_api = Gateways::GoogleVisionAPI.new(api_key)
#           text_result = google_vision_api.detect_text(file_path)

#           view 'display_text', locals: {
#             text: text_result,
#             searched_dishes: session[:searched_dishes] || []
#           }
#         else
#           request.redirect "/?error=#{CGI.escape('No file uploaded. Please upload an image file.')}"
#         end
#       end

#       # DELETE /dish/{dish_name}
#       request.on 'dish' do
#         request.on String do |dish_name|
#           request.delete do
#             session[:searched_dishes].delete(dish_name)
#             request.redirect '/'
#           end
#         end
#       end
#     end
#   end
# end

# frozen_string_literal: true

require 'roda'
require 'slim'
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

          unless dish_name.match?(/\A[\p{L}\s]+\z/u)
            flash[:error] = MESSAGES[:invalid_name]
            routing.redirect '/'
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
                flash[:error] = MESSAGES[:api_error]
                routing.redirect '/'
              end
            end

            if dish&.ingredients&.any?
              # Add to search history
              session[:searched_dishes].insert(0, dish.name).uniq!
              flash[:success] = MESSAGES[:success_created]
              routing.redirect "/display_dish?name=#{CGI.escape(dish_name)}"
            else
              flash[:error] = MESSAGES[:no_ingredients]
              routing.redirect '/'
            end
          rescue StandardError => e
            puts "DB ERROR: #{e.message}"
            flash[:error] = MESSAGES[:db_error]
            routing.redirect '/'
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
