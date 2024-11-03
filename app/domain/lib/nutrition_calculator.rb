# frozen_string_literal: true
# app/domain/lib/nutrition_calculator.rb
require_relative '../values/nutrition_stats'

module MealDecoder
  module Lib
    # Provides methods to calculate nutritional values from given ingredients or dishes.
    class NutritionCalculator

      # Map ingredient names to their calorie values
      CALORIE_VALUES = {
        'beef' => 250, 'steak' => 250, 'ground beef' => 250,
        'chicken' => 165, 'poultry' => 165,
        'pork' => 300, 'ham' => 300, 'bacon' => 300,
        'fish' => 200, 'salmon' => 200, 'tuna' => 200,
        # More mappings as defined previously...
        'default' => 50
      }

      def self.calculate_dish_calories(dish_ingredients)
        return nil if dish_ingredients.empty?

        total_calories = dish_ingredients.sum { |di| di.calories_per_100g }
        ingredient_count = dish_ingredients.size

        Value::NutritionStats.new(
          total_calories: total_calories,
          ingredient_count: ingredient_count,
          avg_calories_per_ingredient: (total_calories / ingredient_count.to_f).round(2)
        )
      end

      # Calculate the calories for a single ingredient
      def self.get_calories(ingredient)
        ingredient = ingredient.downcase
        CALORIE_VALUES.each do |key, cal|
          return cal if ingredient.include?(key)
        end
        CALORIE_VALUES['default']  # Fallback for unknown ingredients
      end
    end
  end
end