# module MealDecoder
#   module Views
#     # View object for rendering a collection of dishes
#     # Handles iteration and counting of dish entities
#     class DishesList
#       def initialize(dishes)
#         puts "DishesList initializing with #{dishes.length} dishes"
#         @dishes = dishes.map do |dish|
#           puts "Creating view for dish: #{dish.name}"
#           Dish.new(dish)
#         end
#       end

#       def any?
#         result = @dishes.any?
#         puts "DishesList#any? returning: #{result}"
#         result
#       end

#       def each(&block)
#         @dishes.each(&block)
#       end

#       def count
#         @dishes.count
#       end
#     end
#   end
# end

# app/presentation/view_objects/dish_list.rb
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
