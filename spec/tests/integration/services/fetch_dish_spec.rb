# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../helpers/database_helper'

describe 'Test FetchDish service' do
  before do
    DatabaseHelper.wipe_database
    @dish_name = 'Test Dish'
    @ingredients = %w[ingredient1 ingredient2]
    @dish = MealDecoder::Entity::Dish.new(
      id: nil,
      name: @dish_name,
      ingredients: @ingredients
    )
  end

  it 'HAPPY: should return Success with dish when found' do
    # Create dish in repository
    MealDecoder::Repository::For.klass(MealDecoder::Entity::Dish).create(@dish)

    # Try to fetch the dish
    result = MealDecoder::Services::FetchDish.new.call(@dish_name)

    _(result).must_be_kind_of Dry::Monads::Success
    _(result.value!.name).must_equal @dish_name
    _(result.value!.ingredients).must_equal @ingredients
  end

  it 'SAD: should return Failure when dish not found' do
    result = MealDecoder::Services::FetchDish.new.call('Nonexistent Dish')

    _(result).must_be_kind_of Dry::Monads::Failure
    _(result.failure).must_equal 'Could not find that dish'
  end
end
