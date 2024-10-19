# frozen_string_literal: true

require_relative 'spec_helper'

describe MealDecoder::Gateways::OpenAIAPI do
  let(:api_key) { MealDecoder.config['OPENAI_API_KEY'] }
  let(:api) { MealDecoder::Gateways::OpenAIAPI.new(api_key) }
  let(:unknown_dish_response) do
    {
      'choices' => [
        { 'message' => { 'content' => "I'm sorry, but I'm not familiar with a dish called 'Xylophone Surprise with Unicorn Tears'. This doesn't appear to be a real or commonly known dish. Could you please provide more information or clarify if this is a specific recipe you're looking for?" } }
      ]
    }.to_json
  end

  it 'HAPPY: should successfully fetch ingredients for a known dish' do
    VCR.use_cassette('chicken_fried_rice') do
      dish_name = 'Chicken Fried Rice'
      ingredients = api.fetch_ingredients(dish_name)
      _(ingredients).wont_be_empty
      _(ingredients).must_be_kind_of String
      _(ingredients).wont_match(/I'm not sure|not familiar with a dish|doesn't refer to a specific dish/)
    end
  end

  it 'SAD: should raise error for an unknown dish' do
    api.set_test_response(unknown_dish_response)

    dish_name = 'Xylophone Surprise with Unicorn Tears'
    _ do
      api.fetch_ingredients(dish_name)
    end.must_raise MealDecoder::Gateways::OpenAIAPI::UnknownDishError
  end

  it 'SAD: should handle API request failure gracefully' do
    VCR.use_cassette('openai_api_failure') do
      dish_name = 'Non-existent Dish'
      error = _(proc { api.fetch_ingredients(dish_name) }).must_raise StandardError
      _(error.message).wont_be_empty
    end
  end
end
