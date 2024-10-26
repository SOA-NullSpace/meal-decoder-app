# frozen_string_literal: true

require_relative '../orm/dish_orm'

module MealDecoder
  module Repository
    # Repository for Dishes
    class Dishes
      def self.find_id(id)
        rebuild_entity Database::DishOrm.first(id:)
      end

      def self.create(entity)
        db_record = Database::DishOrm.find_or_create(name: entity.name)
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        MealDecoder::Entities::Dish.new(
          id: db_record.id,
          name: db_record.name,
          created_at: db_record.created_at,
          updated_at: db_record.updated_at
        )
      end
    end
  end
end
