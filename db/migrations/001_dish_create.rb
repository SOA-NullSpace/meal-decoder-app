# db/migrations/001_dish_create.rb
# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:dishes) do
      primary_key :id
      varchar :name, null: false, unique: true, size: 100
      DateTime :created_at
      DateTime :updated_at
    end
  end

  down do
    drop_table(:dishes)
  end
end
