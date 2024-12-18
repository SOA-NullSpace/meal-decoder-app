# frozen_string_literal: true

module MealDecoder
  module Views
    # View for dish list presentation
    class DishesList
      def initialize(dishes)
        @dishes = dishes.map { |dish_data| Dish.new(dish_data) }
      end

      def any?
        @dishes.any?
      end

      def each(&block)
        @dishes.each(&block)
      end

      def count
        @dishes.count
      end
    end
  end
end
