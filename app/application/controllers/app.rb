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
          if result.success?
            puts "Successfully fetched: #{result.value!}"
            result.value!
          else
            puts "Failed to fetch: #{result.failure}"
            nil
          end
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

          case result
          when Success
            dish_data = result.value!
            puts "Successfully created dish: #{dish_data}"
            # No need to manually update session here as service handles it
            flash[:success] = 'Successfully added new dish!'
            routing.redirect "/display_dish?name=#{CGI.escape(dish_data['name'])}"
          when Failure
            puts "Failed to create dish: #{result.failure}"
            flash[:error] = result.failure
            routing.redirect '/'
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

          case result
          when Success
            view 'dish', locals: {
              title_suffix: result.value!['name'],
              dish: Views::Dish.new(result.value!)
            }
          when Failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        end
      end

      # POST /detect_text - Process menu image
      routing.on 'detect_text' do
        routing.post do
          result = Services::DetectMenuText.new.call(routing.params['image_file'])

          case result
          when Success
            view 'display_text', locals: {
              title_suffix: 'Text Detection',
              text: Views::TextDetection.new(result.value!)
            }
          when Failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        rescue StandardError => e
          puts "TEXT DETECTION ERROR: #{e.message}"
          flash[:error] = 'Error occurred while processing the image'
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

          case result
          when Success
            flash[:success] = 'Dish removed from history'
          when Failure
            flash[:error] = result.failure
          end
        rescue StandardError => e
          puts "DELETE DISH ERROR: #{e.message}"
          flash[:error] = 'Error occurred while removing dish'
        ensure
          routing.redirect '/'
        end
      end
    end
  end
end
