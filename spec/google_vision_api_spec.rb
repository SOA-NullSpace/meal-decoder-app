# frozen_string_literal: true

require 'yaml'
require 'net/http'
require 'json'
require 'base64'
require_relative '../lib/google_vision_api'

RSpec.describe GoogleVisionAPI::TextDetector do
  before do
    @config = YAML.load_file('config/secrets.yml')
  end

  let(:image_path) { File.expand_path('fixtures/text_menu_img.jpeg', __dir__) }
  let(:image_file) { File.open(image_path) }
  let(:detector) { GoogleVisionAPI::TextDetector.new(image_file) }

  it 'detects text in the image' do
    expect { detector.detect_text }.not_to raise_error
  end

  it 'handles no text detected in the image' do
    blank_image_path = File.expand_path('fixtures/blank_img.jpg', __dir__)
    blank_image_file = File.open(blank_image_path)
    blank_detector = GoogleVisionAPI::TextDetector.new(blank_image_file)

    expect { blank_detector.detect_text }.not_to raise_error
  end

  after do
    image_file&.close
  end
end
