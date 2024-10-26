# frozen_string_literal: true

require_relative '../orm/ingredients_orm'

module MealDecoder
  module Repository
    # Repository for Ingredients
    class Ingredients
      def self.find_id(id)
        rebuild_entity Database::IngredientOrm.first(id:)
      end

      def self.create(entity)
        db_record = Database::IngredientOrm.find_or_create(name: entity.name)
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        MealDecoder::Entities::Ingredient.new(
          id: db_record.id,
          name: db_record.name,
          created_at: db_record.created_at,
          updated_at: db_record.updated_at
        )
      end
    end
  end
end
