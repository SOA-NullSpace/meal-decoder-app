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
        calculate_and_create_dish(dish_name, ingredients)
      end

      def calculate_and_create_dish(dish_name, ingredients)
        total_calories = calculate_total_calories(ingredients)
        create_dish_entity(dish_name, ingredients, total_calories)
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

      def calculate_total_calories(ingredients)
        puts "Calculating total calories..."
        ingredients.map { |name| NutritionCalculator.get_calories(name) }.sum
      end

      def create_dish_entity(dish_name, ingredients, total_calories)
        puts "Assembling the Dish entity..."
        MealDecoder::Entity::Dish.new(
          id: nil, name: dish_name, ingredients: ingredients, total_calories: total_calories
        ).tap do |dish|
          puts "Dish created: #{dish.inspect}"
        end
      end

      def log_creation(dish)
        puts "Dish fully prepared and logged: #{dish.inspect}"
      end

      def log_and_raise_error(error)
        puts "ERROR in DishMapper: #{error.class} - #{error.message}"
        puts "Backtrace:\n#{error.backtrace.join("\n")}"
        raise error
      end
    end
  end
end
