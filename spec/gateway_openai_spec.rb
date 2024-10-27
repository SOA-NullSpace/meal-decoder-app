# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'helpers/vcr_helper'
require_relative 'helpers/database_helper'

describe 'Integration Tests of OpenAI API Gateway' do
  VcrHelper.setup_vcr
  DatabaseHelper.wipe_database

  before do
    VcrHelper.configure_vcr_for_apis(CONFIG)
    @api = MealDecoder::Gateways::OpenAIAPI.new(OPENAI_API_KEY)
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Recipe Ingredients Query' do
    it 'HAPPY: should fetch ingredients for a known dish' do
      VCR.use_cassette('openai_known_dish') do
        dish_name = 'Chicken Fried Rice'
        result = @api.fetch_ingredients(dish_name)

        _(result).wont_be_empty
        _(result).must_be_kind_of String
        _(result).must_include 'rice'
        _(result).must_include 'chicken'
        _(result).wont_match(/I'm not sure|not familiar with a dish|doesn't refer to a specific dish/)
      end
    end

    it 'HAPPY: should fetch ingredients for Chinese dishes' do
      VCR.use_cassette('openai_chinese_dish') do
        dish_name = '瘦肉炒麵'
        result = @api.fetch_ingredients(dish_name)

        _(result).wont_be_empty
        _(result).must_be_kind_of String
        _(result).must_match(/noodles|麵|面/i)
        _(result).must_match(/pork|肉/i)
      end
    end
  end

  describe 'API Error Handling' do
    it 'SAD: should raise error for unknown dishes' do
      VCR.use_cassette('openai_unknown_dish') do
        unknown_dish_response = {
          'choices' => [{
            'message' => {
              'content' => "I'm not familiar with a dish called 'Xylophone Surprise with Unicorn Tears'."
            }
          }]
        }.to_json

        @api.set_test_response(unknown_dish_response)

        _(proc do
          @api.fetch_ingredients('Xylophone Surprise with Unicorn Tears')
        end).must_raise MealDecoder::Gateways::OpenAIAPI::UnknownDishError
      end
    end

    it 'SAD: should handle invalid API keys' do
      VCR.use_cassette('openai_invalid_key') do
        invalid_api = MealDecoder::Gateways::OpenAIAPI.new('INVALID_KEY')

        error = _(proc do
          invalid_api.fetch_ingredients('Spaghetti Carbonara')
        end).must_raise StandardError

        _(error.message).must_include 'Incorrect API key provided'
      end
    end

    it 'SAD: should handle API response error' do
      VCR.use_cassette('openai_api_error') do
        error_response = {
          'error' => {
            'message' => 'API request failed'
          }
        }.to_json

        @api.set_test_response(error_response)

        error = _(proc do
          @api.fetch_ingredients('Test Dish')
        end).must_raise StandardError

        _(error.message).must_include 'API error'
      end
    end
  end
end
