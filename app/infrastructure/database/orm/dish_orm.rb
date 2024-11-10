# frozen_string_literal: true

require 'sequel'

module MealDecoder
  module Database
    # Object-Relational Mapper for Dishes
    class DishOrm < Sequel::Model(:dishes)
      plugin :timestamps, update_on_create: true
      plugin :validation_helpers

      def validate
        super
        validates_presence :name
        validates_unique :name
        validates_max_length 100, :name
        validates_format(/^[\p{L}\s]+$/u, :name, message: 'must contain only letters and spaces')
      end

      # Define the relationship between dishes and ingredients
      many_to_many :ingredients,
                   class: :'MealDecoder::Database::IngredientOrm',
                   join_table: :dishes_ingredients,
                   left_key: :dish_id, right_key: :ingredient_id

      # Find existing record or create a new one based on dish name
      def self.find_or_create(dish_info)
        first(name: dish_info[:name]) || create(dish_info)
      end

      # Remove all ingredients associations safely
      def remove_all_ingredients
        Sequel::Model.db.transaction do
          ingredients.each do |ingredient|
            remove_ingredient(ingredient)
          end
        end
      end
    end
  end
end
