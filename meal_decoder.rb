# frozen_string_literal: true

require 'yaml'
require 'dry-struct'
require 'dry-types'
require_relative 'app/models/gateways/google_vision_api'
require_relative 'app/models/gateways/openai_api'
require_relative 'app/models/mappers/dish_mapper'

# Define Types module for use with dry-struct
module Types
  include Dry.Types()
end

# MealDecoder module provides functionality to decode meal information
# from images and fetch ingredients for dishes.
module MealDecoder
  module_function

  def config
    @config ||= YAML.safe_load_file(config_path)
  end

  def config_path
    File.join(File.dirname(__FILE__), 'config', 'secrets.yml')
  end

  def dish_mapper
    @dish_mapper ||= Mappers::DishMapper.new(openai_gateway)
  end

  def run(dish_name)
    dish = dish_mapper.find(dish_name)
    save_ingredients_to_yaml(dish)
    puts 'Ingredients saved successfully.'
  rescue StandardError
    puts "Error: #{e.message}"
  end

  private

  def openai_gateway
    @openai_gateway ||= Gateways::OpenAIAPI.new(config['OPENAI_API_KEY'])
  end

  def save_ingredients_to_yaml(dish)
    File.write(yaml_output_path(dish.name), dish_to_yaml(dish))
  end

  # :reek:UtilityFunction
  def dish_to_yaml(dish)
    { dish.name => dish.ingredients }.to_yaml
  end

  # :reek:UtilityFunction
  def yaml_output_path(dish_name)
    File.join(File.dirname(__FILE__), 'spec', 'fixtures',
              "#{dish_name.downcase.gsub(' ', '_')}_ingredients.yml")
  end
end
