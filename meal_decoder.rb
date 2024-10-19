# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'
require_relative 'lib/gateways/google_vision_api'
require_relative 'lib/gateways/openai_api'
require_relative 'lib/entities/dish'
require_relative 'lib/entities/ingredients'
require_relative 'lib/mappers/dish_mapper'

module MealDecoder
  class << self
    def config
      @config ||= YAML.safe_load_file(config_path)
    end

    def dish_mapper
      @dish_mapper ||= Mappers::DishMapper.new(openai_gateway)
    end

    def run(dish_name)
      dish = dish_mapper.find(dish_name)
      save_ingredients_to_yaml(dish)
      puts 'Ingredients saved successfully.'
    rescue StandardError => e
      puts "Error: #{e.message}"
    end

    private

    def config_path
      File.join(File.dirname(__FILE__), 'config', 'secrets.yml')
    end

    def openai_gateway
      @openai_gateway ||= Gateways::OpenAIAPI.new(config['OPENAI_API_KEY'])
    end

    def save_ingredients_to_yaml(dish)
      output_path = File.join(File.dirname(__FILE__), 'spec', 'fixtures',
                              "#{dish.name.downcase.gsub(' ', '_')}_ingredients.yml")
      File.open(output_path, 'w') { |file| file.write({ dish.name => dish.ingredients }.to_yaml) }
    end
  end
end
