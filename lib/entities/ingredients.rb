# frozen_string_literal: true

module MealDecoder
  module Entities
    class Ingredients
      attr_reader :items

      def initialize(ingredients_text)
        @items = parse_ingredients(ingredients_text)
      end

      def to_a
        @items
      end

      private

      def parse_ingredients(ingredients_text)
        ingredients_text.split("\n").map(&:strip).reject(&:empty?)
      end
    end
  end
end
