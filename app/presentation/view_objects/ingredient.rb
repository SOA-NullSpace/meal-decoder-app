# frozen_string_literal: true

# app/presentation/view_objects/ingredient.rb
# app/presentation/view_objects/ingredient.rb
module MealDecoder
  module Views
    # View object for an ingredient
    class Ingredient
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
        case @name.to_s.downcase
        when /beef|pork|lamb/ then 250
        when /chicken|turkey|duck/ then 165
        when /fish|seafood|shrimp/ then 150
        when /rice|noodle|pasta/ then 130
        when /egg/ then 70
        when /carrot|onion|vegetable|garlic/ then 30
        when /sauce|oil/ then 45
        else 100
        end
      end
    end
  end
end
