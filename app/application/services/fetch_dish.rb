# frozen_string_literal: true

require 'dry/monads'
require 'dry/transaction'

module MealDecoder
  module Services
    # Handles API response processing
    class ResponseHandler
      include Dry::Monads[:result]

      def self.handle_api_response(response, input)
        if response.success?
          Success(input.merge(dish: response.payload))
        else
          Failure(response.message)
        end
      end

      def self.handle_detection_response(response)
        if response.success?
          Success(response.payload['data'])
        else
          Failure(response.message || 'Failed to detect text from image')
        end
      end
    end

    # Service to fetch dish details from API
    class FetchDish
      include Dry::Monads[:result]

      def initialize
        @gateway = Gateway::Api.new(App.config)
      end

      def call(dish_name)
        validate(dish_name)
          .bind { |name| fetch_from_api(name) }
          .bind { |response| handle_response(response) }
      end

      private

      def validate(dish_name)
        if dish_name.to_s.strip.empty?
          Failure('Dish name cannot be empty')
        else
          Success(dish_name)
        end
      end

      def fetch_from_api(dish_name)
        response = @gateway.fetch_dish(dish_name)
        response.success? ? Success(response.payload) : Failure(response.message)
      end

      def handle_response(response_data)
        return Failure('No dish data returned from API') if response_data.nil? || response_data.empty?

        # Extract dish data from the response
        dish_data = response_data['data'] || response_data
        Success(dish_data)
      rescue StandardError => error
        Failure("Could not process dish data: #{error.message}")
      end
    end

    # Service to create new dish and manage history
    class CreateDish
      include Dry::Monads[:result]

      def initialize
        @gateway = Gateway::Api.new(App.config)
      end

      def call(input)
        validate(input)
          .bind { |i| create_dish(i) }
          .bind { |dish_data| update_session(input[:session], dish_data) }
      end

      private

      def validate(input)
        return Failure('Dish name cannot be empty') if input[:dish_name].to_s.strip.empty?
        return Failure('Session is required') unless input[:session]

        validation = Forms::NewDish.new.call(dish_name: input[:dish_name])
        validation.success? ? Success(input) : Failure(validation.errors.messages.join('; '))
      end

      def create_dish(input)
        response = @gateway.create_dish(input[:dish_name])
        if response.success?
          Success(response.payload['data'] || response.payload)
        else
          Failure(response.message || 'Failed to create dish')
        end
      end

      def update_session(session, dish_data)
        return Failure('Invalid dish data') unless dish_data && dish_data['name']

        session[:searched_dishes] ||= []
        session[:searched_dishes].unshift(dish_data['name'])
        session[:searched_dishes].uniq!

        Success(dish_data)
      rescue StandardError => e
        Failure("Session update failed: #{e.message}")
      end
    end

    # Session manager for dish history
    class SessionManager
      def initialize(session)
        @session = session
        @session[:searched_dishes] ||= []
      end

      def add_dish(dish_name)
        return unless dish_name

        searched_dishes.unshift(dish_name)
        searched_dishes.uniq!
      end

      private

      def searched_dishes
        @session[:searched_dishes]
      end
    end

    # Service to process menu image uploads
    class DetectMenuText
      include Dry::Monads[:result]

      def initialize
        @validator = ImageValidator.new
        @gateway = Gateway::Api.new(App.config)
      end

      def call(image_file)
        @validator.validate(image_file)
          .bind { |valid_file| process_image(valid_file) }
      end

      private

      def process_image(image_file)
        response = @gateway.detect_text(image_file[:tempfile].path)
        ResponseHandler.handle_detection_response(response)
      end
    end

    # Service to remove dish from history
    class RemoveDish
      include Dry::Monads[:result]

      def call(dish_name:, session:)
        SessionManager.new(session).remove_dish(dish_name)
        Success('Dish successfully removed from history')
      rescue StandardError => error
        Failure("Failed to remove dish: #{error.message}")
      end
    end

    # Validates image file uploads
    class ImageValidator
      include Dry::Monads[:result]

      def initialize
        @validation_form = Forms::ImageFileUpload.new
        @image_file = nil
      end

      def validate(image_file)
        @image_file = image_file
        return Failure('No image file provided') unless valid_file?

        validate_with_form
      end

      private

      attr_reader :image_file

      def valid_file?
        image_file && image_file[:tempfile]
      end

      def validate_with_form
        validation = @validation_form.call(image_file: image_attributes)
        validation.success? ? Success(image_file) : Failure(validation.errors.messages.join('; '))
      end

      def image_attributes
        {
          tempfile: image_file[:tempfile],
          type: image_file[:type],
          filename: image_file[:filename]
        }
      end
    end
  end
end
