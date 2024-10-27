# frozen_string_literal: true

# The MealDecoder module encapsulates all entities related to the MealDecoder application.
module MealDecoder
  module Entity
    # The Ingredients class is designed to handle the processing and representation
    # of ingredients from a given text. It parses the text into an array of ingredients,
    # providing access to the list as an array via the `to_a` method.
    class Ingredient
      def self.parse_ingredients(ingredients_text)
        # Clean up and split the text into an array of ingredients
        ingredients = ingredients_text.split("\n")
                                   .map(&:strip)
                                   .reject(&:empty?)

        # Remove any bullet points or numbers at the start of ingredients
        ingredients.map do |ingredient|
          ingredient.gsub(/^[\d\s.*•-]*/, '').strip
        end.reject(&:empty?)
      end
    end
  end
end
