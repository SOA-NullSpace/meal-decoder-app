# frozen_string_literal: true

module MealDecoder
  module Views
    # Classifies dishes based on their names for view presentation
    class DishClassifier
      DISH_TYPES = {
        soup: /soup|stew|broth/i,
        salad: /salad|slaw/i,
        sandwich: /sandwich|burger/i,
        pizza: /pizza/i,
        pasta: /pasta|noodle/i
      }.freeze

      def self.determine_type(name)
        DISH_TYPES.find do |type, pattern|
          return type if name.match?(pattern)
        end
        :main_dish
      end
    end
  end
end
