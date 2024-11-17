# frozen_string_literal: true

require_relative '../../spec_helper'

describe 'Test Forms - Image File Upload' do
  before do
    @temp_file = Tempfile.new(['test_img', '.jpg'])
    File.write(@temp_file, 'fake image content')
  end

  after do
    @temp_file.close
    @temp_file.unlink
  end

  it 'HAPPY: should validate proper image files' do
    good_file = {
      'image_file' => {
        filename: 'test.jpg',
        type: 'image/jpeg',
        tempfile: @temp_file
      }
    }

    validation = MealDecoder::Forms::ImageFileUpload.new.call(good_file)

    _(validation.success?).must_equal true
    _(validation.errors.messages).must_be_empty
  end

  it 'SAD: should reject non-image files' do
    bad_file = {
      'image_file' => {
        filename: 'test.pdf',
        type: 'application/pdf',
        tempfile: @temp_file
      }
    }

    validation = MealDecoder::Forms::ImageFileUpload.new.call(bad_file)

    _(validation.success?).must_equal false
    _(validation.errors.messages.first.text).must_include 'must be a JPG, PNG, or GIF'
  end

  it 'SAD: should reject files with wrong extension' do
    bad_extension = {
      'image_file' => {
        filename: 'test.txt',
        type: 'image/jpeg',
        tempfile: @temp_file
      }
    }

    validation = MealDecoder::Forms::ImageFileUpload.new.call(bad_extension)

    _(validation.success?).must_equal false
    _(validation.errors.messages.first.text).must_include 'must have a valid image extension'
  end

  it 'SAD: should reject when image file is missing' do
    validation = MealDecoder::Forms::ImageFileUpload.new.call({})

    _(validation.success?).must_equal false
    _(validation.errors.messages.first.text).must_include 'is missing'
  end
end
