# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../spec_helper'

module MealDecoder
  describe 'Integration Tests of Google Vision API Gateway' do
    include MiniTestSetup

    before do
      @config = OpenStruct.new(
        OPENAI_API_KEY:,
        GOOGLE_CLOUD_API_TOKEN:
      )
      VcrHelper.configure_vcr_for_apis(@config)
      @api = Gateways::GoogleVisionAPI.new(GOOGLE_CLOUD_API_TOKEN)
      @results = YAML.safe_load_file('spec/fixtures/google_vision_results.yml')
    end

    describe 'Text Detection' do
      it 'HAPPY: should detect Chinese menu text correctly' do
        VCR.use_cassette('google_vision_text_menu', record: :new_episodes) do
          image_path = File.join(__dir__, '../../../fixtures/text_menu_img.jpeg')
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
    end
  end
end
