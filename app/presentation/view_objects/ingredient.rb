# app/presentation/view_objects/ingredient.rb
module MealDecoder
  module Views
    # View object for an ingredient
    class Ingredient
      attr_reader :name, :amount, :unit

      def initialize(entity)
        @entity = entity
        @name = entity.name
        @amount = entity.amount
        @unit = entity.unit
      end

      def formatted_amount
        "#{amount} #{unit}".strip
      end

      def calories
        MealDecoder::Lib::NutritionCalculator.get_calories(@entity)
      end

      def display_calories
        "#{calories} cal"
      end

      def to_s
        [formatted_amount, name].reject(&:empty?).join(' ')
      end

      def full_display
        "#{self} (#{display_calories})"
      end
    end
  end
end
