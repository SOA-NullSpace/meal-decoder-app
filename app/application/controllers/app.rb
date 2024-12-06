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
    module ResultHandler
      include Dry::Monads[:result]

      def self.handle_service_result(result, routing)
        case result
        in Success(value)
          yield(value)
        in Failure(message)
          handle_failure(message, routing)
        end
      end

      def self.handle_failure(message, routing)
        routing.flash[:error] = message
        routing.redirect '/'
      end
    end

    route do |routing|
      # Clear any existing flash before processing new request
      previous_flash = flash.dup
      flash.clear

      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public

      # GET / - Home page with search history
      routing.root do
        # Disable caching for dynamic content
        response.headers['Cache-Control'] = 'no-store'
        session[:searched_dishes] ||= []
        puts "Current session dishes: #{session[:searched_dishes]}"

        # Only keep flash for the first render after redirect
        flash.merge!(previous_flash) if routing.params['flash'] == 'keep'

        dishes = session[:searched_dishes].map do |dish_name|
          result = Services::FetchDish.new.call(dish_name)
          result.value_or(nil)
        end.compact

        view 'home', locals: {
          title_suffix: 'Home',
          dishes: Views::DishesList.new(dishes)
        }
      end

      # POST /fetch_dish - Create or retrieve dish information
      routing.on 'fetch_dish' do
        routing.post do
          dish_name = routing.params['dish_name']

          result = Services::CreateDish.new.call(
            {
              dish_name: dish_name,
              session: session
            }
          )

          case result
          in Success(dish_data)
            flash[:success] = 'Successfully added new dish!'
            routing.redirect "/display_dish?name=#{CGI.escape(dish_data['name'])}&flash=keep", 303
          in Failure(message)
            flash[:error] = message
            routing.redirect '/?flash=keep', 303
          end
        end
      end

      # GET /display_dish - Show detailed dish information
      routing.on 'display_dish' do
        routing.get do
          flash.merge!(previous_flash) if routing.params['flash'] == 'keep'

          dish_name = CGI.unescape(routing.params['name'].to_s)
          result = Services::FetchDish.new.call(dish_name)

          case result
          in Success(dish_data)
            view 'dish', locals: {
              title_suffix: dish_data['name'],
              dish: Views::Dish.new(dish_data)
            }
          in Failure(message)
            flash[:error] = message
            routing.redirect '/?flash=keep', 303
          end
        end
      end

      # POST /detect_text - Process menu image
      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          dish_name = CGI.unescape(encoded_dish_name)
          result = Services::RemoveDish.new.call(
            dish_name: dish_name,
            session: session
          )

          case result
          in Success(_)
            response.headers['Cache-Control'] = 'no-cache, no-store'
            flash[:success] = 'Dish removed from history'
          in Failure(message)
            response.status = 400
            flash[:error] = message
          end
          routing.redirect '/?flash=keep', 303
        end
      end

      # DELETE /dish/{name} - Remove dish from history
      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          dish_name = CGI.unescape(encoded_dish_name)
          result = Services::RemoveDish.new.call(
            dish_name: dish_name,
            session: session
          )

          case result
          in Success(_)
            # Clear caches and set no-cache headers
            response.headers['Cache-Control'] = 'no-cache, no-store'
            flash[:success] = 'Dish removed from history'
          in Failure(message)
            response.status = 400
            flash[:error] = "Failed to remove dish: #{message}"
          end

          # Force reload of home page
          # Add a parameter to indicate we should keep the flash for one render
          routing.redirect '/?flash=keep', 303
        end
      end
    end

    private

    def flash
      request.session['flash'] ||= {}
    end

    def session
      request.session
    end
  end
end
