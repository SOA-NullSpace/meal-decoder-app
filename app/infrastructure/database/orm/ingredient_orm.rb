# frozen_string_literal: true

require 'sequel'

module MealDecoder
  module Database
    # Object-Relational Mapper for Ingredients
    class IngredientOrm < Sequel::Model(:ingredients)
      # Define the relationship back to dishes
      many_to_many :dishes,
                   class: :'MealDecoder::Database::DishOrm',
                   join_table: :dishes_ingredients,
                   left_key: :ingredient_id, right_key: :dish_id

      # Automatic management of created_at and updated_at fields
      plugin :timestamps, update_on_create: true

      # Find existing record or create a new one based on ingredient name
      def self.find_or_create(ingredient_info)
        first(name: ingredient_info[:name]) || create(ingredient_info)
      end
    end
  end
end
