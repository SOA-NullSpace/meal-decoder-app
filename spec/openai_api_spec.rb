# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Meal Decoder' do
  describe 'Ingredient Fetching' do
    before do
      @api_key = MealDecoder.config['OPENAI_API_KEY']
      @ingredient_service = MealDecoder::Service::IngredientFetcher.new(@api_key)
    end

    it 'HAPPY: should successfully fetch ingredients for a known dish' do
      VCR.use_cassette('chicken_tikka_masala') do
        dish_name = 'Chicken Tikka Masala'
        ingredients = @ingredient_service.fetch_ingredients(dish_name)
        _(ingredients).wont_be_empty
        _(ingredients).must_be_kind_of String
        _(ingredients).wont_match(/I'm not sure|not familiar with a dish|doesn’t refer to a specific dish/)
      end
    end

    it 'SAD: should raise NotFound error for an unknown dish' do
      VCR.use_cassette('unknown_dish') do
        dish_name = 'Unknown Dish'
        _ do
          @ingredient_service.fetch_ingredients(dish_name)
        end.must_raise MealDecoder::Service::IngredientFetcher::NotFound
      end
    end

    it 'SAD: should handle API request failure gracefully' do
      VCR.use_cassette('openai_api_failure') do
        dish_name = 'Non-existent Dish'
        error = _(proc { @api.fetch_ingredients(dish_name) }).must_raise StandardError
        _(error.message).wont_be_empty
      end
    end
  end
end
