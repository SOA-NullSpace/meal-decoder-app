# frozen_string_literal: true

require_relative '../../../domain/entities/dish'
require_relative '../../../domain/entities/ingredient'
require_relative '../../../domain/lib/nutrition_calculator'

module MealDecoder
  module Mappers
    # DishMapper is responsible for mapping data retrieved via the OpenAI API
    # into a structured Dish entity. It fetches ingredients data, parses it,
    # and assembles a Dish entity with these ingredients.
    class DishMapper
      def initialize(openai_gateway)
        @openai_gateway = openai_gateway
      end

      def find(dish_name)
        puts "\n=== Starting the dish lookup process for: #{dish_name} ==="
        prepare_and_log_dish(dish_name)
      rescue StandardError => error
        log_and_raise_error(error)
      end

      private

      def prepare_and_log_dish(dish_name)
        dish = fetch_and_prepare_dish(dish_name)
        log_creation(dish)
        dish
      end

      def fetch_and_prepare_dish(dish_name)
        ingredients_text = fetch_ingredients_text(dish_name)
        ingredients = parse_ingredients(ingredients_text)
        create_dish_entity(dish_name, ingredients)
      end

      def fetch_ingredients_text(dish_name)
        puts "Retrieving ingredients from OpenAI for: #{dish_name}"
        @openai_gateway.fetch_ingredients(dish_name).tap do |ingredients_text|
          puts "Ingredients retrieved: #{ingredients_text}"
        end
      end

      def parse_ingredients(ingredients_text)
        puts "Parsing ingredients list..."
        MealDecoder::Entity::Ingredient.parse_ingredients(ingredients_text)
      end

      def create_dish_entity(dish_name, ingredients)
        puts "Assembling the Dish entity..."
        
        # Create the dish without nutrition stats first
        MealDecoder::Entity::Dish.new(
          id: nil,
          name: dish_name,
          ingredients: ingredients
        ).tap do |dish|
          puts "Created dish: #{dish.inspect}"
          dish
        end
      end

      def log_creation(dish)
        puts "Dish created: #{dish.inspect}"
        dish
      end

      def log_and_raise_error(error)
        puts "ERROR in DishMapper: #{error.class} - #{error.message}"
        puts "Backtrace:\n#{error.backtrace.join("\n")}"
        raise error
      end

      # Create a proper ingredient object that responds to calories_per_100g
      class IngredientWithCalories
        attr_reader :calories_per_100g
        
        def initialize(calories)
          @calories_per_100g = calories
        end
      end
    end
  end
end
