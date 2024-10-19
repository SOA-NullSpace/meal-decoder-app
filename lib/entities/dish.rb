# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

module Types
  include Dry.Types()
end

module MealDecoder
  module Entities
    class Dish < Dry::Struct
      attribute :name, Types::Strict::String
      attribute :ingredients, Types::Array.of(Types::Strict::String)
    end
  end
end
