# frozen_string_literal: true

require_relative '../entities/dish'
require_relative '../entities/ingredients'

module MealDecoder
  module Mappers
    # responsible for orchestrating the flow of data between OpenAIAPI gateway and the Dish entity
    class DishMapper
      def initialize(openai_gateway)
        @openai_gateway = openai_gateway
      end

      def find(dish_name)
        ingredients_text = @openai_gateway.fetch_ingredients(dish_name)
        Entities::Dish.new(
          name: dish_name,
          ingredients: Entities::Ingredients.parse_ingredients(ingredients_text)
        )
      end
    end
  end
end
