# frozen_string_literal: true

require_relative '../orm/dish_orm'

module MealDecoder
  module Repository
    # Repository for Dishes
    class Dishes
      def self.find_id(id)
        rebuild_entity Database::DishOrm.first(id:)
      end

      def self.find_name(name)
        rebuild_entity Database::DishOrm.first(name:)
      end

      def self.create(entity)
        return nil unless entity

        db_dish = Database::DishOrm.find_or_create(name: entity.name)

        # Handle ingredients
        entity.ingredients.each do |ingredient_name|
          ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
          db_dish.add_ingredient(ingredient) unless db_dish.ingredients.include?(ingredient)
        end

        rebuild_entity(db_dish)
      end

      def self.delete(id)
        Database::DishOrm.where(id:).delete
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Dish.new(
          id: db_record.id,
          name: db_record.name,
          ingredients: db_record.ingredients.map(&:name)
        )
      end
    end
  end
end
