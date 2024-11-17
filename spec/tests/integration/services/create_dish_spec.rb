# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../spec_helper'

# Application domain entity and value objects for the MealDecoder service
# Implements core business logic for dish creation and management
module MealDecoder
  describe 'Test CreateDish service' do
    include MiniTestSetup

    before do
      @session = { searched_dishes: [] }
      @config = OpenStruct.new(
        OPENAI_API_KEY:,
        GOOGLE_CLOUD_API_TOKEN:
      )
      VcrHelper.configure_vcr_for_apis(@config)
    end

    it 'HAPPY: should create new dish and add to history' do
      VCR.use_cassette('service_create_pizza') do
        result = Services::CreateDish.new.call(
          dish_name: 'Pizza',
          session: @session
        )

        _(result).must_be_kind_of Dry::Monads::Success
        _(result.value!.name).must_equal 'Pizza'
        _(@session[:searched_dishes]).must_include 'Pizza'
      end
    end

    it 'SAD: should return Failure for invalid API response' do
      VCR.use_cassette('service_create_invalid_dish') do
        result = Services::CreateDish.new.call(
          dish_name: 'NotARealDish123',
          session: @session
        )

        _(result).must_be_kind_of Dry::Monads::Failure
        _(result.failure).must_include 'API Error'
      end
    end
  end
end
