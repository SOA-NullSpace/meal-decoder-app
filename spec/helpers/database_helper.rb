# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    # Ignore foreign key constraints when wiping tables
    db = MealDecoder::App.db
    db.run('PRAGMA foreign_keys = OFF')
    MealDecoder::Database::DishOrm.map(&:destroy)
    MealDecoder::Database::IngredientOrm.map(&:destroy)
    db.run('PRAGMA foreign_keys = ON')
  end
end
