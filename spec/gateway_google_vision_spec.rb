# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'helpers/vcr_helper'
require_relative 'helpers/database_helper'

describe 'Integration Tests of Google Vision API Gateway' do
  VcrHelper.setup_vcr
  DatabaseHelper.wipe_database

  before do
    VcrHelper.configure_vcr_for_apis(CONFIG)
    @api = MealDecoder::Gateways::GoogleVisionAPI.new(GOOGLE_CLOUD_API_TOKEN)
    @results = YAML.safe_load_file('spec/fixtures/google_vision_results.yml')
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Text Detection' do
    it 'HAPPY: should detect Chinese menu text correctly' do
      VCR.use_cassette('google_vision_text_menu') do
        image_path = File.join(__dir__, 'fixtures', 'text_menu_img.jpeg')
        result = @api.detect_text(image_path)

        _(result).wont_be_empty
        # Check for specific menu items
        _(@results['text_menu_img']['text']).must_include '瘦肉炒麵'
        _(@results['text_menu_img']['text']).must_include '海鮮炒麵'
        _(@results['text_menu_img']['text']).must_include '牛肉炒麵'

        # Check full text matches
        _(result).must_equal @results['text_menu_img']['text']
      end
    end

    it 'HAPPY: should handle images without text' do
      VCR.use_cassette('google_vision_blank') do
        image_path = File.join(__dir__, 'fixtures', 'blank_img.jpg')
        result = @api.detect_text(image_path)

        _(result).must_be_empty
        _(result).must_equal @results['blank_img']['text']
      end
    end

    it 'SAD: should raise error for nonexistent files' do
      _(proc do
        @api.detect_text('nonexistent_image.jpg')
      end).must_raise Errno::ENOENT
    end
  end

  describe 'API Error Handling' do
    it 'SAD: should handle invalid credentials properly' do
      VCR.use_cassette('google_vision_unauthorized') do
        unauthorized_api = MealDecoder::Gateways::GoogleVisionAPI.new('BAD_TOKEN')

        error = _(proc do
          unauthorized_api.detect_text(
            File.join(__dir__, 'fixtures', 'text_menu_img.jpeg')
          )
        end).must_raise RuntimeError

        _(error.message).must_equal @results['error_responses']['bad_request']
      end
    end

    it 'SAD: should handle malformed requests properly' do
      VCR.use_cassette('google_vision_bad_request') do
        # Create a zero-byte temp file to simulate invalid image
        Tempfile.create(['bad_image', '.jpg']) do |temp_file|
          error = _(proc do
            @api.detect_text(temp_file.path)
          end).must_raise RuntimeError

          _(error.message).must_include 'API request failed'
        end
      end
    end
  end
end
