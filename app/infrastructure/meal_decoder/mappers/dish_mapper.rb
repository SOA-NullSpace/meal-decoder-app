# frozen_string_literal: true

require_relative '../../../models/entities/dish'
require_relative '../../../models/entities/ingredient'

module MealDecoder
  module Mappers
    # Mapper to convert OpenAI API responses into Dish entities
    class DishMapper
      def initialize(openai_gateway)
        @openai_gateway = openai_gateway
      end

      def find(dish_name)
        puts "\n=== DishMapper.find for: #{dish_name} ==="

        # Get ingredients text from OpenAI
        puts "Calling OpenAI gateway..."
        ingredients_text = @openai_gateway.fetch_ingredients(dish_name)
        puts "Received ingredients text: #{ingredients_text}"

        # Parse ingredients text into array
        puts "Parsing ingredients..."
        ingredients = Entity::Ingredient.parse_ingredients(ingredients_text)
        puts "Parsed ingredients: #{ingredients.inspect}"

        # Create and return a new Dish entity
        puts "Creating Dish entity..."
        dish = Entity::Dish.new(
          id: nil,  # Explicitly set id to nil for new dishes
          name: dish_name,
          ingredients: ingredients
        )
        puts "Created dish: #{dish.inspect}"
        puts "=== End DishMapper.find ===\n"

        dish
      rescue StandardError => e
        puts "ERROR in DishMapper: #{e.class} - #{e.message}"
        puts "Backtrace:\n#{e.backtrace.join("\n")}"
        raise
      end
    end
  end
end
