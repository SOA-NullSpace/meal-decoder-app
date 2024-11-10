# frozen_string_literal: true

require_relative '../orm/dish_orm'
require_relative '../../../domain/lib/nutrition_calculator'

module MealDecoder
  module Repository
    # Repository for Dishes
    class Dishes
      def self.find_id(id)
        rebuild_entity Database::DishOrm.first(id: id)
      end

      def self.find_name(name)
        rebuild_entity Database::DishOrm.first(name: name)
      end

      def self.create(entity)
        return nil unless entity

        db_dish = Database::DishOrm.find_or_create(name: entity.name)
        handle_ingredients(db_dish, entity.ingredients)
        rebuild_entity(db_dish)
      end

      def self.handle_ingredients(db_dish, ingredient_names)
        ingredient_names.each do |ingredient_name|
          ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
          db_dish.add_ingredient(ingredient) unless db_dish.ingredients.include?(ingredient)
        end
      end

      def self.delete(id)
        return nil unless id

        begin
          Sequel::Model.db.transaction do
            # First, delete all associations in the join table
            Sequel::Model.db[:dishes_ingredients].where(dish_id: id).delete
            # Then delete the dish
            Sequel::Model.db[:dishes].where(id: id).delete
          end
        rescue Sequel::Error => e
          puts "Database deletion error: #{e.message}"
          nil
        end
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        ingredients = db_record.ingredients
        total_calories = calculate_calories(ingredients)

        Entity::Dish.new(
          id: db_record.id,
          name: db_record.name,
          ingredients: ingredients.map(&:name),
          total_calories: total_calories
        )
      end

      private

      def self.calculate_calories(ingredients)
        ingredients.sum { |ingredient| Lib::NutritionCalculator.get_calories(ingredient.name) }
      end
    end
  end
end
