# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/rg'
require 'yaml'
require_relative '../lib/google_vision_api'

CONFIG = YAML.safe_load(File.read('config/secrets.yml'))
API_KEY = CONFIG['GOOGLE_CLOUD_API_TOKEN']

describe MealDecoder::GoogleVisionAPI do
  let(:api) { MealDecoder::GoogleVisionAPI.new }

  describe 'initialization' do
    it 'loads API key correctly' do
      api_key = api.instance_variable_get(:@api_key)
      _(api_key).must_be_kind_of String
      _(api_key).wont_be_empty
    end
  end

  describe 'text detection' do
    it 'detects text in an image with text' do
      image_path = File.join(__dir__, 'fixtures', 'text_menu_img.jpeg')
      result = api.detect_text(image_path)

      _(result).wont_be_empty
      _(result.downcase).must_include '瘦肉炒麵' # Assuming the menu image contains the word "menu"
    end

    it 'returns empty string for image without text' do
      image_path = File.join(__dir__, 'fixtures', 'blank_img.jpg')
      result = api.detect_text(image_path)

      _(result).must_be_empty
    end

    it 'raises exception on invalid image path' do
      _(proc do
        api.detect_text('non_existent_image.jpg')
      end).must_raise Errno::ENOENT
    end
  end

  describe 'error handling' do
    it 'raises exception when API request fails' do
      Net::HTTP.stub :start, ->(*) { Net::HTTPBadRequest.new('1.1', '400', 'Bad Request') } do
        _(proc do
          api.detect_text(File.join(__dir__, 'fixtures', 'text_menu_img.jpeg'))
        end).must_raise RuntimeError
      end
    end

    it 'raises exception when unauthorized' do
      Net::HTTP.stub :start, ->(*) { Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized') } do
        _(proc do
          api.detect_text(File.join(__dir__, 'fixtures', 'text_menu_img.jpeg'))
        end).must_raise MealDecoder::GoogleVisionAPI::Errors::Unauthorized
      end
    end
  end
end
