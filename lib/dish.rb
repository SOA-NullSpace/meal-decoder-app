# frozen_string_literal: true

module MealDecoder
  module Entity
    class Dish
      attr_reader :name, :ingredients

      def initialize(name:, ingredients:)
        @name = name
        @ingredients = ingredients
      end
    end
  end
end
