# frozen_string_literal: true

module MealDecoder
  module Views
    # View for dish presentation
    class Dish
      attr_reader :id, :name, :total_calories

      def initialize(data)
        @id = data['id']
        @name = data['name']
        @raw_ingredients = data['ingredients'] || []
        @total_calories = data['total_calories'].to_i
        @calorie_level = data['calorie_level']
      end

      def ingredients
        @ingredients ||= @raw_ingredients.map { |ing| Ingredient.new(name: ing) }
      end

      def has_ingredients?
        ingredients.any?
      end

      def ingredients_count
        ingredients.size
      end

      def calorie_class
        case total_calories
        when 0..500 then 'success'
        when 501..800 then 'warning'
        else 'danger'
        end
      end

      def calorie_level
        @calorie_level || case total_calories
                         when 0..400 then 'Low Calorie'
                         when 401..700 then 'Medium Calorie'
                         else 'High Calorie'
                         end
      end
    end
  end
end
