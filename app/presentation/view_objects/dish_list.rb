# app/presentation/view_objects/dishes_list.rb
module MealDecoder
  module Views
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