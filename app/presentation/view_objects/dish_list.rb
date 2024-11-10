module MealDecoder
  module Views
    # View object for rendering a collection of dishes
    # Handles iteration and counting of dish entities
    class DishesList
      def initialize(dishes)
        @dishes = dishes.map { |dish| Dish.new(dish) }
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
