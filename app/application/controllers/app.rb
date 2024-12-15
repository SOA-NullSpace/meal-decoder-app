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
      flash[:error] = 'An unexpected error occurred'
      response.status = 500
      view 'home', locals: {
        title_suffix: 'Error',
        dishes: Views::DishesList.new([])
      }
    end

    private

    def gateway
      @gateway ||= Gateway::Api.new(App.config)
    end

    def parse_json_request(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      puts "JSON parsing error: #{e.message}"
      {}
    end

    def add_to_history(dish_name)
      session[:searched_dishes] ||= []
      # Remove existing entry if present
      session[:searched_dishes].delete(dish_name)
      # Add to the beginning of the array
      session[:searched_dishes].unshift(dish_name)
      # Keep only the most recent MAX_HISTORY_SIZE dishes
      session[:searched_dishes] = session[:searched_dishes].take(MAX_HISTORY_SIZE)
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

      # POST /dishes - Create new dish
      routing.on 'dishes' do
        routing.post do
          request_data = parse_json_request(routing.body.read)

          unless request_data['dish_name']
            response.status = 400
            return { error: 'Dish name is required' }.to_json
          end

          result = gateway.create_dish(request_data['dish_name'])
          puts "Create dish response: #{result.inspect}"

          if result.success?
            response.status = result.status == :processing ? 202 : 201

            # Extract channel information for WebSocket progress tracking
            channel_id = result.payload.dig('data', 'channel_id')
            progress_info = if channel_id
                              {
                                channel: "/progress/#{channel_id}",
                                endpoint: "#{App.config.API_HOST}/faye"
                              }
                            end

            # Add to history if the dish is created successfully
            add_to_history(request_data['dish_name']) if result.payload['status'] == 'completed'

            {
              status: result.payload['status'],
              message: result.payload['message'],
              data: result.payload['data'],
              progress: progress_info
            }.to_json
          else
            response.status = 400
            {
              error: result.message,
              details: result.payload&.dig('error', 'details')
            }.to_json
          end
        rescue StandardError => e
          puts "ERROR creating dish: #{e.inspect}"
          puts e.backtrace
          response.status = 500
          {
            error: 'Could not process dish request',
            details: e.message
          }.to_json
        end

        # GET /dishes/:id - Get dish by ID
        routing.on Integer do |id|
          routing.get do
            result = gateway.fetch_dish(id)

            if result.success?
              dish_name = result.payload['name']
              add_to_history(dish_name) if dish_name

              view 'dish', locals: {
                title_suffix: result.payload['name'],
                dish: Views::Dish.new(result.payload)
              }
            else
              flash[:error] = result.message
              routing.redirect '/'
            end
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
            # Add to search history
            add_to_history(dish_name)

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
          puts 'Received text detection request'

          unless routing.params['image_file']
            flash[:error] = 'Please select an image file'
            routing.redirect '/'
            next
          end

          # Log incoming file details
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
            flash[:error] = result.failure
            routing.redirect '/'
          end
        rescue StandardError => e
          puts "ERROR in detect_text: #{e.class} - #{e.message}"
          puts e.backtrace
          flash[:error] = 'Error occurred while processing the image'
          routing.redirect '/'
        end
      end

      # DELETE /dish/{name} - Remove dish from history
      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          dish_name = CGI.unescape(encoded_dish_name)
          session[:searched_dishes]&.delete(dish_name)
          flash[:success] = 'Dish removed from history'
          routing.redirect '/'
        end
      end

      def flash_error(message)
        flash[:error] = message
        routing.redirect '/'
      end
    end
  end
end
