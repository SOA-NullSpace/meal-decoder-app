# frozen_string_literal: true

require 'sequel'

module MealDecoder
  module Database
    # Object-Relational Mapper for Dishes
    class DishOrm < Sequel::Model(:dishes)
      # Define the relationship between dishes and ingredients
      many_to_many :ingredients,
                   class: :'MealDecoder::Database::IngredientOrm',
                   join_table: :dishes_ingredients,
                   left_key: :dish_id, right_key: :ingredient_id

      # Automatic management of created_at and updated_at fields
      plugin :timestamps, update_on_create: true

      # Find existing record or create a new one based on dish name
      def self.find_or_create(dish_info)
        first(name: dish_info[:name]) || create(dish_info)
      end
    end
  end
end
