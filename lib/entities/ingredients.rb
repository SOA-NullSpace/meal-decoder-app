# frozen_string_literal: true

# The MealDecoder module encapsulates all entities related to the MealDecoder application.
module MealDecoder
  module Entities
    # The Ingredients class is designed to handle the processing and representation
    # of ingredients from a given text. It parses the text into an array of ingredients,
    # providing access to the list as an array via the `to_a` method.
    class Ingredients
      attr_reader :items

      # Initializes the Ingredients object with a text containing ingredients,
      # each expected to be on a new line.
      def initialize(ingredients_text)
        @items = parse_ingredients(ingredients_text)
      end

      def to_a
        @items
      end

      def self.parse_ingredients(ingredients_text)
        ingredients_text.split("\n").map(&:strip).reject(&:empty?)
      end
    end
  end
end
