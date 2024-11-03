# frozen_string_literal: true

require_relative '../../../domain/entities/dish'
require_relative '../../../domain/entities/ingredient'

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
        ingredients = MealDecoder::Entity::Ingredient.parse_ingredients(ingredients_text)
        puts "Parsed ingredients: #{ingredients.inspect}"

        dish_ingredients = ingredients.map { |name| calculate_ingredient_calories(name) }
        total_calories = dish_ingredients.sum { |ing| ing[:calories] }

        # Create and return a new Dish entity
        puts "Creating Dish entity..."
        dish = MealDecoder::Entity::Dish.new(
          id: nil,  # Explicitly set id to nil for new dishes
          name: dish_name,
          ingredients: ingredients,
          total_calories: total_calories
        )
        puts "Created dish: #{dish.inspect}"
        puts "=== End DishMapper.find ===\n"

        dish
      rescue StandardError => error
        puts "ERROR in DishMapper: #{e.class} - #{e.message}"
        puts "Backtrace:\n#{e.backtrace.join("\n")}"
        raise
      end

      private

       def calculate_ingredient_calories(ingredient_name)
        calories = case ingredient_name.downcase
                  when /chicken|beef|pork|fish/ then 250.0
                  when /rice|pasta|bread|noodle/ then 130.0
                  when /cheese|butter/ then 400.0
                  when /vegetable|carrot|broccoli|spinach|lettuce/ then 50.0
                  when /oil/ then 900.0
                  when /sauce|dressing/ then 100.0
                  else 120.0
                  end
        { name: ingredient_name, calories: calories }
      end
    end
  end
end