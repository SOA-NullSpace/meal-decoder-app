# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/rg'
require_relative '../lib/meal_decoder' 

describe 'Meal Decoder' do
  describe 'Ingredient Fetching' do
    before do
      @api_key = MealDecoder.config['OPENAI_API_KEY']
      @ingredient_service = MealDecoder::Service::IngredientFetcher.new(@api_key)
    end

    it 'HAPPY: should successfully fetch ingredients for a known dish' do
      dish_name = 'Chicken Tikka Masala'  
      ingredients = @ingredient_service.fetch_ingredients(dish_name)
      _(ingredients).wont_be_empty
      _(ingredients).must_be_kind_of String
      _(ingredients).wont_match /I'm not sure|not familiar with a dish|doesn’t refer to a specific dish/
    end

    it 'SAD: should raise NotFound error for an unknown dish' do
      dish_name = 'Unknown Dish' 
      _ { @ingredient_service.fetch_ingredients(dish_name) }.must_raise MealDecoder::Service::IngredientFetcher::NotFound
    end
  end
end
