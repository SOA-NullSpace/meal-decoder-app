# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'Test CreateDish service' do
  VcrHelper.setup_vcr
  DatabaseHelper.wipe_database

  before do
    @session = { searched_dishes: [] }
    @config = OpenStruct.new(
      OPENAI_API_KEY: OPENAI_API_KEY,
      GOOGLE_CLOUD_API_TOKEN: GOOGLE_CLOUD_API_TOKEN
    )
    VcrHelper.configure_vcr_for_apis(@config)
  end

  after do
    VcrHelper.eject_vcr
  end

  it 'HAPPY: should create new dish and add to history' do
    VCR.use_cassette('service_create_pizza') do
      result = MealDecoder::Services::CreateDish.new.call(
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
      result = MealDecoder::Services::CreateDish.new.call(
        dish_name: 'NotARealDish123',
        session: @session
      )

      _(result).must_be_kind_of Dry::Monads::Failure
      _(result.failure).must_include 'API Error'
    end
  end
end
