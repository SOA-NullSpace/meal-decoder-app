# frozen_string_literal: true

module MealDecoder
  module Views
    # View object for an ingredient
    class Ingredient
      CALORIE_MAP = {
        'beef|pork|lamb'                => 250,
        'chicken|turkey|duck'           => 165,
        'fish|seafood|shrimp'           => 150,
        'rice|noodle|pasta'             => 130,
        'egg'                           => 70,
        'carrot|onion|vegetable|garlic' => 30,
        'sauce|oil'                     => 45
      }.freeze

      DEFAULT_CALORIES = 100

      attr_reader :name, :amount, :unit

      def initialize(entity)
        @name = entity.name
        @amount = entity.amount
        @unit = entity.unit
      end

      def formatted_amount
        return @name unless @amount || @unit

        [@amount, @unit, @name].compact.join(' ')
      end

      def display_calories
        "#{calculate_calories} cal"
      end

      def to_s
        formatted_amount
      end

      private

      def calculate_calories
        CALORIE_MAP.each do |pattern, calories|
          return calories if @name.to_s.downcase.match?(pattern)
        end
        DEFAULT_CALORIES
      end
    end
  end
end
