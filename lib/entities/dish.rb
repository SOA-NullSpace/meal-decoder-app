# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

# The Types module includes the type definitions used across the application.
module Types
  include Dry.Types()
end

# The MealDecoder module encapsulates all entities related to the MealDecoder application.
module MealDecoder
  module Entities
    # The Dish class represents a dish with a name and a list of ingredients.
    # It uses dry-struct to ensure the attributes conform to specified data types.
    class Dish < Dry::Struct
      attribute :name, Types::Strict::String
      attribute :ingredients, Types::Array.of(Types::Strict::String)
    end
  end
end
