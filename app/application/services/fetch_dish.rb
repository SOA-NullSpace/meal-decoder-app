require 'dry/monads'
require 'dry/transaction'

module MealDecoder
  module Services
    # Service to fetch dish details
    class FetchDish
      include Dry::Monads[:result]

      def call(dish_name)
        # Try to find dish in repository
        dish = Repository::For.klass(Entity::Dish).find_name(dish_name)

        if dish
          Success(dish)
        else
          Failure('Could not find that dish')
        end
      rescue StandardError => e
        Failure("Error fetching dish: #{e.message}")
      end
    end

    # Service to create new dish from API
    class CreateDish
      include Dry::Transaction

      step :validate_input
      step :fetch_from_api
      step :save_to_repository
      step :add_to_history

      private

      def validate_input(input)
        if input[:dish_name].nil? || input[:dish_name].empty?
          Failure('Dish name is required')
        else
          Success(input)
        end
      end

      def fetch_from_api(input)
        api_key = App.config.OPENAI_API_KEY
        api = Gateways::OpenAIAPI.new(api_key)
        mapper = Mappers::DishMapper.new(api)

        Success(input.merge(dish: mapper.find(input[:dish_name])))
      rescue StandardError => e
        Failure("API Error: #{e.message}")
      end

      def save_to_repository(input)
        # Delete existing dish if it exists
        if existing = Repository::For.klass(Entity::Dish).find_name(input[:dish_name])
          Repository::For.klass(Entity::Dish).delete(existing.id)
        end

        # Create new dish
        dish = Repository::For.klass(Entity::Dish).create(input[:dish])
        Success(input.merge(dish:))
      rescue StandardError => e
        Failure("Database Error: #{e.message}")
      end

      def add_to_history(input)
        session = input[:session]
        dish_name = input[:dish]&.name

        searched_dishes = session[:searched_dishes] ||= []
        searched_dishes.insert(0, dish_name).uniq!

        Success(input[:dish])
      rescue StandardError => e
        Failure("Session Error: #{e.message}")
      end
    end

    # Service to process image uploads and detect text
    class DetectMenuText
      include Dry::Monads[:result]

      def call(image_file)
        api = Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
        text_result = api.detect_text(image_file[:tempfile].path)

        Success(text_result)
      rescue StandardError => e
        Failure("Text detection error: #{e.message}")
      end
    end

    # Service to remove dish from history
    class RemoveDish
      include Dry::Transaction

      step :validate_input
      step :remove_from_history
      step :delete_from_database

      private

      def validate_input(input)
        if input[:dish_name].nil? || input[:dish_name].empty?
          Failure('Dish name is required')
        else
          Success(input)
        end
      end

      def remove_from_history(input)
        session = input[:session]
        dish_name = input[:dish_name]

        searched_dishes = session[:searched_dishes] ||= []
        searched_dishes.delete(dish_name)

        Success(input)
      rescue StandardError => e
        Failure("Session Error: #{e.message}")
      end

      def delete_from_database(input)
        if dish = Repository::For.klass(Entity::Dish).find_name(input[:dish_name])
          Repository::For.klass(Entity::Dish).delete(dish.id)
        end

        Success('Dish removed successfully')
      rescue StandardError => e
        Failure("Database Error: #{e.message}")
      end
    end
  end
end
