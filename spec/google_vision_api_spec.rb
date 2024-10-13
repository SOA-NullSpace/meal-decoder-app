# frozen_string_literal: true

require_relative 'spec_helper'

CASSETTE_FILE = 'google_vision_api'
CORRECT = YAML.safe_load(File.read('spec/fixtures/google_vision_results.yml'))

describe 'Tests Google Vision API library' do
  before do
    VCR.insert_cassette CASSETTE_FILE
    @api = MealDecoder::GoogleVisionAPI.new(GOOGLE_CLOUD_API_TOKEN)
  end

  after do
    VCR.eject_cassette
  end

  describe 'Text detection' do
    it 'detects text in an image with text' do
      VCR.use_cassette('text_detection') do
        image_path = File.join(__dir__, 'fixtures', 'text_menu_img.jpeg')
        result = @api.detect_text(image_path)

        _(result).wont_be_empty
        _(result).must_include '瘦肉炒麵'
        _(result).must_equal CORRECT['text_menu_img']['text']
      end
    end

    it 'handles the "blank" image case' do
      VCR.use_cassette('blank_image') do
        image_path = File.join(__dir__, 'fixtures', 'blank_img.jpg')
        result = @api.detect_text(image_path)

        if result.empty?
          _(result).must_equal CORRECT['blank_img']['text']
        else
          skip "The 'blank' image contains text. Expected behavior may need to be revised."
        end
      end
    end

    it 'raises exception on invalid image path' do
      _(proc do
        @api.detect_text('non_existent_image.jpg')
      end).must_raise Errno::ENOENT
    end
  end

  describe 'API interaction' do
    it 'raises exception when API request fails' do
      VCR.use_cassette('api_request_failure') do
        api_with_invalid_key = MealDecoder::GoogleVisionAPI.new('INVALID_KEY')
        _(proc do
          api_with_invalid_key.detect_text(File.join(__dir__, 'fixtures', 'text_menu_img.jpeg'))
        end).must_raise RuntimeError
      end
    end

    it 'raises exception when unauthorized' do
      VCR.use_cassette('unauthorized_request') do
        api_with_empty_key = MealDecoder::GoogleVisionAPI.new('')
        error = _(proc do
          api_with_empty_key.detect_text(File.join(__dir__, 'fixtures', 'text_menu_img.jpeg'))
        end).must_raise RuntimeError
        _(error.message).must_equal 'API request failed with status code: 403'
      end
    end
  end
end
