# app/presentation/view_objects/dish.rb
# frozen_string_literal: true

module MealDecoder
  module Views
    class Dish
      attr_reader :name, :ingredients, :total_calories, :calorie_level

      def initialize(data)
        @name = data['name']
        @ingredients = create_ingredients(data['ingredients'])
        @total_calories = data['total_calories'].to_i
        @calorie_level = data['calorie_level'] || calculate_calorie_level
      end

      def has_ingredients?
        @ingredients&.any?
      end

      def ingredients_count
        @ingredients&.size || 0
      end

      def calorie_class
        case @calorie_level&.downcase
        when 'high' then 'danger'    # Will render as red
        when 'moderate' then 'warning'  # Will render as yellow
        when 'low' then 'success'    # Will render as green
        else 'secondary'             # Default gray
        end
      end

      private

      def create_ingredients(ingredients_data)
        return [] if ingredients_data.nil?

        ingredients_data.map do |ingredient_name|
          Views::Ingredient.new(
            OpenStruct.new(
              name: ingredient_name,
              amount: nil,
              unit: nil
            )
          )
        end
      end

      def calculate_calorie_level
        case @total_calories
        when 0..400 then 'Low'
        when 401..700 then 'Moderate'
        else 'High'
        end
      end
    end
  end
end
