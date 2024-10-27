# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    # Ignore foreign key constraints when wiping tables
    MealDecoder::App.db.run('PRAGMA foreign_keys = OFF')
    MealDecoder::Database::DishOrm.map(&:destroy)
    MealDecoder::Database::IngredientOrm.map(&:destroy)
    MealDecoder::App.db.run('PRAGMA foreign_keys = ON')
  end
end
