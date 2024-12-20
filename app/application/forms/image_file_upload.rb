# frozen_string_literal: true

require 'dry-validation'

module MealDecoder
  module Forms
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
          unless valid_types.include?(value[:type].to_s.downcase)
            key.failure('must be a JPG, PNG, or GIF image')
          end

          valid_extensions = /\.(jpg|jpeg|png|gif)$/i
          unless value[:filename].to_s.match?(valid_extensions)
            key.failure('must have a valid image extension (.jpg, .png, or .gif)')
          end

          if value[:tempfile].size > 5 * 1024 * 1024 # 5MB limit
            key.failure('must be smaller than 5MB')
          end
        end
      end
    end
  end
end

