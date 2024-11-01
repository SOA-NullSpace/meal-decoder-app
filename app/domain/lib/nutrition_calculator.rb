# frozen_string_literal: true
# app/domain/lib/nutrition_calculator.rb
require_relative '../values/nutrition_stats'

module MealDecoder
  module Lib
    class NutritionCalculator
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
    end
  end
end