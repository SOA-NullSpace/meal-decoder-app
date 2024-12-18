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
    plugin :json
    plugin :json_parser
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/public'
    plugin :assets,
           path: 'app/presentation/assets',
           css: 'style.css',
           js: 'layout.js'
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

    MAX_HISTORY_SIZE = 10 # Maximum number of dishes to keep in history

    configure do
      use Rack::MethodOverride
      use Rack::Session::Cookie,
          key: 'rack.session',
          secret: config.SESSION_SECRET,
          same_site: :strict
    end

    def self.api_host
      @api_host ||= ENV.fetch('API_HOST', 'http://localhost:9292')
    end

    # Handle all errors
    error do |error|
      puts "ERROR: #{error.inspect}"
      puts error.backtrace
      flash[:error] = case error
                      when Roda::RodaError
                        'Invalid request'
                      else
                        'An unexpected error occurred'
                      end
      if request.path.end_with?('.ico')
        response.status = 404
        nil
      else
        response.status = 500
        view 'home', locals: {
          title_suffix: 'Error',
          dishes: Views::DishesList.new([])
        }
      end
    end

    # Helper methods should be defined at class level, before the route block
    def self.gateway
      @gateway ||= Gateway::Api.new(config)
    end

    def self.parse_json_request(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      puts "JSON parsing error: #{e.message}"
      {}
    end

    def self.add_to_history(session, dish_name)
      session[:searched_dishes] ||= []
      session[:searched_dishes].delete(dish_name)
      session[:searched_dishes].unshift(dish_name)
      session[:searched_dishes] = session[:searched_dishes].take(MAX_HISTORY_SIZE)
    end

    def self.handle_failure(flash, routing, message)
      flash[:error] = message
      routing.redirect '/'
    end

    def self.handle_success(flash, routing, message)
      flash[:success] = message
      routing.redirect '/'
    end

    def self.handle_api_error(response, routing, flash, message)
      if routing.accepts?('application/json')
        response.status = 400
        { error: message }.to_json
      else
        flash[:error] = message
        routing.redirect '/'
      end
    end

    def self.handle_404(response, flash, routing)
      response.status = 404
      flash[:error] = 'Resource not found'
      routing.redirect '/'
    end

    route do |routing|
      @current_route = routing # Save routing for helper methods

      routing.assets # load CSS
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public # load favicon

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

      # POST /dishes - Create new dish from selection
      routing.on 'dishes' do
        routing.post do
          request_data = self.class.parse_json_request(routing.body.read)
          result = self.class.gateway.create_dish(request_data['dish_name'])

          if result.success?
            response.status = result.payload['status'] == 'processing' ? 202 : 201

            # Add to history if dish was created successfully
            self.class.add_to_history(session, request_data['dish_name']) if result.status == :completed

            channel_id = result.payload.dig('data', 'channel_id')
            progress_info = if channel_id
                              {
                                channel: "/progress/#{channel_id}",
                                endpoint: "#{App.api_host}/faye"
                              }
                            end

            {
              status: result.payload['status'],
              message: result.payload['message'],
              data: result.payload['data'],
              progress: progress_info
            }.to_json
          else
            response.status = 400
            {
              error: true,
              message: result.message
            }.to_json
          end
        rescue StandardError => e
          puts "ERROR creating dish: #{e.inspect}"
          response.status = 500
          {
            error: true,
            message: 'Failed to process dish request'
          }.to_json
        end

        # GET /dishes/:id - Show dish details
        routing.get Integer do |id|
          result = self.class.gateway.fetch_dish(id)

          if result.success?
            view 'dish', locals: {
              dish: Views::Dish.new(result.payload),
              title_suffix: result.payload['name']
            }
          else
            self.class.handle_failure(flash, routing, result.message)
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
            self.class.add_to_history(session, dish_name)
            view 'dish', locals: {
              title_suffix: result.value!['name'],
              dish: Views::Dish.new(result.value!)
            }
          when Failure
            self.class.handle_failure(flash, routing, result.failure)
          end
        end
      end

      # POST /detect_text - Process menu image
      routing.on 'detect_text' do
        routing.post do
          puts 'Received text detection request'

          self.class.handle_failure(flash, routing, 'Please select an image file') unless routing.params['image_file']

          image_file = routing.params['image_file']
          puts "Processing image: #{image_file[:filename]} (#{image_file[:type]})"

          result = Services::DetectMenuText.new.call(image_file)

          case result
          when Success
            detected_text = result.value!
            puts "Successfully detected #{detected_text.length} lines of text"

            view 'display_text', locals: {
              title_suffix: 'Text Detection',
              text: Views::TextDetection.new(detected_text)
            }
          when Failure
            puts "Text detection failed: #{result.failure}"
            self.class.handle_failure(flash, routing, result.failure)
          end
        rescue StandardError => e
          puts "ERROR in detect_text: #{e.class} - #{e.message}"
          puts e.backtrace
          self.class.handle_failure(flash, routing, 'Error occurred while processing the image')
        end
      end

      # DELETE /dish/{name} - Remove dish from history
      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          dish_name = CGI.unescape(encoded_dish_name)
          session[:searched_dishes]&.delete(dish_name)
          self.class.handle_success(flash, routing, 'Dish removed from history')
        end
      end
    end
  end
end
