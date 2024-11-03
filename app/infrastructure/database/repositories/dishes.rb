# frozen_string_literal: true

require_relative '../orm/dish_orm'

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
        # Handle ingredients
        # entity.ingredients.each do |ingredient_name|
        #   ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
        #   db_dish.add_ingredient(ingredient) unless db_dish.ingredients.include?(ingredient)
        # end
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
        Database::DishOrm.where(id:).delete
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record
        ingredients = db_record.ingredients
        total_calories = calculate_total_calories(ingredients)

        Entity::Dish.new(
          id: db_record.id,
          name: db_record.name,
          ingredients: ingredients.map(&:name),
          total_calories: total_calories
        )
      end

      # def self.calculate_total_calories(ingredients)
      #   ingredients.sum do |ingredient|
      #     case ingredient.name.downcase
      #     when /chicken|beef|pork|fish/ then 250.0
      #     when /rice|pasta|bread|noodle/ then 130.0
      #     when /cheese|butter/ then 400.0
      #     when /vegetable|carrot|broccoli|spinach|lettuce/ then 50.0
      #     when /oil/ then 900.0
      #     when /sauce|dressing/ then 100.0
      #     else 120.0
      #     end
      #   end
      # end

      def self.calculate_total_calories(ingredients)
        MealDecoder::Lib::NutritionCalculator.calculate_calories_for_ingredients(ingredients.map(&:name))
      end
    end
  end
end
