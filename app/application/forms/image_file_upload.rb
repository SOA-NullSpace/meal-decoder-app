# frozen_string_literal: true

require 'dry-validation'

module MealDecoder
  module Forms
    # Form validation contract for image file uploads
    # Validates file type, size, and extension for menu image processing
    class ImageFileUpload < Dry::Validation::Contract
      params do
        required(:image_file).filled(:hash) do
          required(:tempfile).filled
          required(:type).filled(:string)
          required(:filename).filled(:string)
        end
      end

      rule(:image_file) do
        if value
          key.failure('must provide an image file') unless value.key?(:tempfile)

          valid_types = ['image/jpeg', 'image/png', 'image/gif']
          key.failure('must be a JPG, PNG, or GIF image') unless valid_types.include?(value[:type].to_s.downcase)

          valid_extensions = /\.(jpg|jpeg|png|gif)$/i
          unless value[:filename].to_s.match?(valid_extensions)
            key.failure('must have a valid image extension (.jpg, .png, or .gif)')
          end

          key.failure('must be smaller than 5MB') if value[:tempfile].size > 5 * 1024 * 1024 # 5MB limit
        end
      end
    end
  end
end
