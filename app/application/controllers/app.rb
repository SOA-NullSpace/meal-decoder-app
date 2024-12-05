# frozen_string_literal: true

require 'roda'
require 'slim'
require 'rack'
require 'dry/monads'

module MealDecoder
  # Web App
  class App < Roda
    include Dry::Monads[:result]

    plugin :caching
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/assets'
    plugin :static, ['/assets']
    plugin :flash
    plugin :all_verbs
    plugin :request_headers
    plugin :common_logger, $stderr
    plugin :halt
    plugin :error_handler
    plugin :sessions,
           key: 'meal_decoder.session',
           secret: config.SESSION_SECRET

    use Rack::MethodOverride

    # Handle all errors
    error do |error|
      puts "ERROR: #{error.inspect}"
      puts error.backtrace
      flash[:error] = 'An unexpected error occurred'
      response.status = 500
      view 'home', locals: {
        title_suffix: 'Error',
        dishes: Views::DishesList.new([])
      }
    end

    # Result handling helper
    class ResultHandler
      def self.handle_service_result(result, routing)
        case result
        when Success
          yield(result.value!)
        when Failure
          handle_failure(result.failure, routing)
        end
      end

      def self.handle_failure(message, routing)
        routing.flash[:error] = message
        routing.redirect '/'
      end
    end

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public

      # GET / - Home page with search history
      routing.root do
        response.cache_control public: true, max_age: 60
        session[:searched_dishes] ||= []
        puts "Current session dishes: #{session[:searched_dishes]}"

        dishes = session[:searched_dishes].map do |dish_name|
          puts "Fetching dish: #{dish_name}"
          result = Services::FetchDish.new.call(dish_name)
          result.value_or(nil)
        end.compact

        puts "Final dishes data: #{dishes}"

        view 'home', locals: {
          title_suffix: 'Home',
          dishes: Views::DishesList.new(dishes)
        }
      end

      # POST /fetch_dish - Create or retrieve dish information
      routing.on 'fetch_dish' do
        routing.post do
          puts "Received dish_name: #{routing.params['dish_name']}"

          result = Services::CreateDish.new.call(
            dish_name: routing.params['dish_name'],
            session:
          )

          ResultHandler.handle_service_result(result, routing) do |dish_data|
            puts "Successfully created dish: #{dish_data}"
            routing.flash[:success] = 'Successfully added new dish!'
            routing.redirect "/display_dish?name=#{CGI.escape(dish_data['name'])}"
          end
        end
      end

      # GET /display_dish - Show detailed dish information
      routing.on 'display_dish' do
        routing.get do
          if App.environment == :production
            response.expires 60, public: true
            response.headers['Cache-Control'] = 'public, must-revalidate'
          end

          dish_name = CGI.unescape(routing.params['name'].to_s)
          puts "Displaying dish: #{dish_name}"

          result = Services::FetchDish.new.call(dish_name)

          ResultHandler.handle_service_result(result, routing) do |dish_data|
            view 'dish', locals: {
              title_suffix: dish_data['name'],
              dish: Views::Dish.new(dish_data)
            }
          end
        end
      end

      # POST /detect_text - Process menu image
      routing.on 'detect_text' do
        routing.post do
          result = Services::DetectMenuText.new.call(routing.params['image_file'])

          ResultHandler.handle_service_result(result, routing) do |text_data|
            view 'display_text', locals: {
              title_suffix: 'Text Detection',
              text: Views::TextDetection.new(text_data)
            }
          end
        rescue StandardError => error
          puts "TEXT DETECTION ERROR: #{error.message}"
          routing.flash[:error] = 'Error occurred while processing the image'
          routing.redirect '/'
        end
      end

      # DELETE /dish/{name} - Remove dish from history
      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          dish_name = CGI.unescape(encoded_dish_name)
          result = Services::RemoveDish.new.call(
            dish_name:,
            session:
          )

          ResultHandler.handle_service_result(result, routing) do |_|
            routing.flash[:success] = 'Dish removed from history'
            routing.redirect '/'
          end
        rescue StandardError => error
          puts "DELETE DISH ERROR: #{error.message}"
          routing.flash[:error] = 'Error occurred while removing dish'
          routing.redirect '/'
        end
      end
    end
  end
end
