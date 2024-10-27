# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'helpers/vcr_helper'
require_relative 'helpers/database_helper'

describe 'Integration Tests of External APIs and Database' do
  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr_for_apis(CONFIG)
    DatabaseHelper.wipe_database
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Retrieve and store dish information' do
    it 'HAPPY: should be able to save dish from OpenAI API to database' do
      VCR.use_cassette('openai_spaghetti_carbonara') do
        # Create a dish using the API
        dish_name = 'Spaghetti Carbonara'
        api_dish = MealDecoder::Mappers::DishMapper
          .new(MealDecoder::Gateways::OpenAIAPI.new(CONFIG['OPENAI_API_KEY']))
          .find(dish_name)

        # Store it in the database using the repository
        stored_dish = MealDecoder::Repository::For.entity(api_dish).create(api_dish)

        # Verify the stored dish matches the original
        _(stored_dish.id).wont_be_nil
        _(stored_dish.name).must_equal(dish_name)
        _(stored_dish.ingredients.count).must_equal(api_dish.ingredients.count)

        # Verify each ingredient was stored correctly
        api_dish.ingredients.each do |ingredient|
          _(stored_dish.ingredients).must_include ingredient
        end
      end
    end

    it 'HAPPY: should be able to update existing dish with new ingredients' do
      VCR.use_cassette('openai_pizza_updates') do
        # First create a dish
        dish_name = 'Classic Pizza'
        api = MealDecoder::Gateways::OpenAIAPI.new(CONFIG['OPENAI_API_KEY'])
        mapper = MealDecoder::Mappers::DishMapper.new(api)

        first_stored = MealDecoder::Repository::For.entity(
          mapper.find(dish_name)
        ).create(mapper.find(dish_name))

        original_ingredients_count = first_stored.ingredients.count

        # Update the same dish
        updated_stored = MealDecoder::Repository::For.entity(
          mapper.find(dish_name)
        ).create(mapper.find(dish_name))

        # Verify the update
        _(updated_stored.id).must_equal(first_stored.id)
        _(updated_stored.name).must_equal(first_stored.name)
        _(updated_stored.ingredients.count).must_be :>=, original_ingredients_count
      end
    end

    it 'SAD: should gracefully handle invalid dish names' do
      # Test name longer than database limit
      too_long_name = 'x' * 101  # Exceeds 100 character limit

      # First test: name too long
      _(proc do
        MealDecoder::Database::DishOrm.create(
          name: too_long_name
        )
      end).must_raise Sequel::ValidationFailed

      # Second test: invalid characters in name
      invalid_name = 'Pizza!!!123'  # Contains invalid characters

      _(proc do
        MealDecoder::Database::DishOrm.create(
          name: invalid_name
        )
      end).must_raise Sequel::ValidationFailed

      # Third test: empty name (null constraint)
      _(proc do
        MealDecoder::Database::DishOrm.create(
          name: ''
        )
      end).must_raise Sequel::ValidationFailed
    end
  end

  describe 'Retrieve and store detected text' do
    before do
      @vision_results = YAML.safe_load_file('spec/fixtures/google_vision_results.yml')
    end

    it 'HAPPY: should be able to process and store text from image' do
      VCR.use_cassette('google_vision_text_menu') do
        image_path = File.join(__dir__, 'fixtures', 'text_menu_img.jpeg')
        api = MealDecoder::Gateways::GoogleVisionAPI.new(CONFIG['GOOGLE_CLOUD_API_TOKEN'])

        detected_text = api.detect_text(image_path)
        _(detected_text).wont_be_empty

        # Verify against known test results
        _(detected_text).must_include '瘦肉炒麵'
        _(detected_text).must_equal @vision_results['text_menu_img']['text']
      end
    end
  end
end
