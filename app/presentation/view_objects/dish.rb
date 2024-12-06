# frozen_string_literal: true

module MealDecoder
  module Views
    # Presents raw dish data in a structured format
    class DishPresenter
      def initialize(data)
        @raw_data = data
      end

      def name
        @raw_data['name']
      end

      def id
        @raw_data['id']
      end

      def total_calories
        @raw_data['total_calories'].to_i
      end

      def calorie_level
        @raw_data['calorie_level']
      end

      def raw_ingredients
        @raw_data['ingredients'] || []
      end
    end

    # View object representing a dish with its presentation logic
    class Dish
      def initialize(data)
        @presenter = DishPresenter.new(data)
      end

      def id
        @presenter.id
      end

      def name
        @presenter.name
      end

      def ingredients
        @ingredients ||= @presenter.raw_ingredients.map { |ing| Ingredient.new(name: ing) }
      end

      def ingredients?
        ingredients.any?
      end

      def ingredients_count
        ingredients.size
      end

      def total_calories
        @presenter.total_calories
      end

      def calorie_class
        case total_calories
        when 0..500 then 'success'
        when 501..800 then 'warning'
        else 'danger'
        end
      end

      def calorie_level
        @presenter.calorie_level || calculate_calorie_level
      end

      private

      def calculate_calorie_level
        case total_calories
        when 0..400 then 'Low Calorie'
        when 401..700 then 'Medium Calorie'
        else 'High Calorie'
        end
      end
    end
  end
end
