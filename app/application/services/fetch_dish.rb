# frozen_string_literal: true

require 'dry/monads'
require 'dry/transaction'

module MealDecoder
  module Services
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
        if dish_name.nil? || dish_name.strip.empty?
          Failure('Dish name cannot be empty')
        else
          Success(dish_name)
        end
      end

      def fetch_from_api(dish_name)
        response = @gateway.fetch_dish(dish_name)
        if response.success?
          Success(response.payload)
        else
          Failure(response.message)
        end
      end

      def handle_response(response_data)
        return Failure('No dish data returned from API') if response_data.nil?

        Success(response_data)
      rescue StandardError => e
        Failure("Could not process dish data: #{e.message}")
      end
    end

    # Factory for creating API-related objects
    class APIFactory
      def self.create_gateway
        Gateway::Api.new(App.config)
      end
    end

    # Service to create new dish and manage processing
    class CreateDish
      include Dry::Monads[:result]

      def initialize
        @gateway = Gateway::Api.new(App.config)
      end

      def call(input)
        validate(input)
          .bind { |data| create_dish(data) }
          .bind { |response| handle_response(response) }
      end

      private

      def validate(input)
        if input[:dish_name].nil? || input[:dish_name].strip.empty?
          Failure('Dish name cannot be empty')
        else
          Success(input)
        end
      end

      def create_dish(input)
        result = @gateway.create_dish(input[:dish_name])
        puts "API create_dish result: #{result.inspect}"
        Success(result)
      rescue StandardError => e
        puts "Error creating dish: #{e.message}"
        Failure("Failed to create dish: #{e.message}")
      end

      def handle_response(response)
        if response.success?
          Success(Response::ApiResult.new(
                    status: response.payload['status'].to_sym,
                    message: response.payload['message'],
                    data: response.payload['data']
                  ))
        else
          Failure(response.message)
        end
      end
    end

    # Service to handle text detection from images
    class DetectMenuText
      include Dry::Monads[:result]

      def initialize
        @gateway = Gateway::Api.new(App.config)
      end

      def call(image_file)
        validate(image_file)
          .bind { |file| detect_text(file) }
      end

      private

      def validate(image_file)
        return Failure('No image file provided') unless image_file && image_file[:tempfile]

        validation = Forms::ImageFileUpload.new.call(image_file: {
                                                       tempfile: image_file[:tempfile],
                                                       type: image_file[:type],
                                                       filename: image_file[:filename]
                                                     })

        if validation.success?
          Success(image_file)
        else
          Failure(validation.errors.messages.join('; '))
        end
      end

      def detect_text(image_file)
        response = @gateway.detect_text(image_file[:tempfile].path)

        if response.success?
          Success(response.payload['data'])
        else
          Failure(response.message || 'Failed to detect text from image')
        end
      rescue StandardError => e
        puts "Text detection error: #{e.message}"
        puts e.backtrace
        Failure("Failed to process image: #{e.message}")
      end
    end

    # Service to remove dish from history
    class RemoveDish < Dry::Validation::Contract
      include Dry::Monads[:result]

      params do
        required(:dish_name).filled(:string)
        required(:session).filled(:hash)
      end

      def call(input)
        dish_name = input[:dish_name]
        session = input[:session]

        remove_from_session(dish_name, session)
          .bind { |_| remove_from_database(dish_name) }
      end

      private

      def remove_from_session(dish_name, session)
        session[:searched_dishes] ||= []
        session[:searched_dishes].delete(dish_name)
        Success(dish_name)
      rescue StandardError => e
        Failure("Failed to remove from session: #{e.message}")
      end

      def remove_from_database(dish_name)
        dish = Repository::For.klass(Entity::Dish).find_name(dish_name)
        if dish
          Repository::For.klass(Entity::Dish).delete_by_id(dish.id)
          Success('Dish successfully removed')
        else
          Success('Dish not found in database')
        end
      rescue StandardError => e
        Failure("Failed to remove from database: #{e.message}")
      end
    end
  end
end
