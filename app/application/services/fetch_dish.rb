# frozen_string_literal: true

require 'dry/monads'
require 'dry/transaction'

module MealDecoder
  module Services
    # Handles processing and validation of API responses
    class ResponseProcessor
      def self.process_payload(response)
        payload = response.payload
        data = payload['data']
        return data if data

        payload
      end

      def self.format_error(error_message)
        "Failed to process dish data: #{error_message}"
      end

      def self.validate_dish_data(dish_data)
        dish_data && dish_data['name'].to_s.strip.present?
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
        return Failure('Dish name cannot be empty') if dish_name.to_s.strip.empty?

        Success(dish_name)
      end

      def fetch_from_api(dish_name)
        response = @gateway.fetch_dish(dish_name)
        response.success? ? Success(response.payload) : Failure(response.message)
      end

      def handle_response(response_data)
        return Failure('No dish data returned from API') if response_data.empty?

        Success(response_data)
      rescue StandardError => error
        Failure(ResponseProcessor.format_error(error.message))
      end
    end

    # Input wrapper for dish creation
    class CreateDishInput
      include Dry::Monads[:maybe]

      def initialize(params)
        @params = params
      end

      def dish_name
        @params[:dish_name].to_s
      end

      def session
        Maybe(@params[:session])
      end

      def valid?
        !dish_name.strip.empty? && session.some?
      end
    end

    # Service to create new dish and manage history
    class CreateDish
      include Dry::Monads[:result]

      def initialize
        @gateway = Gateway::Api.new(App.config)
        @validator = Forms::NewDish.new
      end

      def call(input_params)
        @input = CreateDishInput.new(input_params)
        validate_input
          .bind { |valid_input| create_dish(valid_input) }
          .bind { |dish_data| update_session(dish_data) }
      end

      private

      attr_reader :input

      def validate_input
        validation = @validator.call(dish_name: input.dish_name)
        return Failure(validation.errors.messages.join('; ')) unless validation.success?
        return Failure('Session is required') unless input.valid?

        Success(input)
      end

      def create_dish(valid_input)
        response = @gateway.create_dish(valid_input.dish_name)
        return Failure(response.message) unless response.success?

        Success(ResponseProcessor.process_payload(response))
      end

      def update_session(dish_data)
        SessionUpdateContext.new(input.session.value!, dish_data).update
      end
    end

    # Manages dish history in session state
    class SessionManager
      def initialize(session)
        @session = session
        @searched_dishes = nil
        ensure_session_initialized
      end

      def add_dish(dish_name)
        return unless dish_name

        initialize_if_needed
        @searched_dishes.unshift(dish_name)
        @searched_dishes.uniq!
      end

      def remove_dish(dish_name)
        return false if dish_name.to_s.strip.empty?

        initialize_if_needed
        return false unless @searched_dishes.include?(dish_name)

        @searched_dishes.delete(dish_name)
        true
      end

      private

      def initialize_if_needed
        ensure_session_initialized unless @searched_dishes
      end

      def ensure_session_initialized
        @searched_dishes = @session[:searched_dishes] ||= []
      end
    end

    # Value object for session update operations
    class SessionUpdateContext
      include Dry::Monads[:result]

      def initialize(session, dish_data)
        @session = session
        @dish_data = dish_data
      end

      def update
        validate_and_update
      end

      private

      def validate_and_update
        validate
          .bind { |data| perform_update(data) }
          .bind { |_| Success(@dish_data) }
      rescue StandardError => error
        Failure("Session update failed: #{error.message}")
      end

      def validate
        return Failure('Invalid dish data') unless ResponseProcessor.validate_dish_data(@dish_data)

        Success(@dish_data)
      end

      def perform_update(data)
        manager = SessionManager.new(@session)
        manager.add_dish(data['name'])
        Success(true)
      end
    end

    # Value object for dish removal operations
    class DishRemovalContext
      include Dry::Monads[:result]

      attr_reader :dish_name, :session

      def initialize(dish_name:, session:)
        @dish_name = dish_name
        @session = session
      end

      def valid?
        !dish_name.to_s.strip.empty? && session
      end

      def error_message
        return 'Dish name cannot be empty' if dish_name.to_s.strip.empty?
        return 'Session is required' unless session

        nil
      end

      def remove
        return Failure(error_message) unless valid?

        manager = SessionManager.new(session)
        name = dish_name # cache to avoid multiple calls
        if manager.remove_dish(name)
          Success(true)
        else
          Failure("Could not find dish '#{name}' in history")
        end
      end
    end

    # Service to remove dish from history
    class RemoveDish
      include Dry::Monads[:result]

      def call(params)
        DishRemovalContext.new(**params)
          .remove
          .fmap { |_| 'Dish successfully removed from history' }
      rescue StandardError => error
        Failure("Failed to remove dish: #{error.message}")
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
        validate_and_process(image_file)
          .bind { |response| extract_text(response) }
      end

      private

      def validate_and_process(image_file)
        @validator.validate(image_file)
          .bind { |valid_file| process_image(valid_file) }
      rescue StandardError => error
        Failure("Image processing failed: #{error.message}")
      end

      def process_image(image_file)
        response = @gateway.detect_text(image_file[:tempfile].path)
        response.success? ? Success(response.payload) : Failure(response.message)
      end

      def extract_text(response)
        text_data = response['data']
        return Failure('No text detected in image') unless text_data && !text_data.empty?

        Success(text_data)
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
