# frozen_string_literal: true

require_relative 'dish'
require_relative 'openai_api'
require 'yaml'

module MealDecoder
  def self.config
    config_path = File.join(File.dirname(File.expand_path(__dir__)), 'config', 'secrets.yml')
    @config ||= YAML.safe_load_file(config_path)
  end

  def self.ingredient_service
    @ingredient_service ||= Service::IngredientFetcher.new(config['OPENAI_API_KEY'])
  end

  def self.run(dish_name)
    ingredients = ingredient_service.fetch_ingredients(dish_name)
    Utils.save_ingredients_to_yaml(dish_name, ingredients)
  rescue StandardError => e
    puts "Error fetching ingredients: #{e.message}"
  end
end

module Utils
  def self.save_ingredients_to_yaml(dish_name, ingredients)
    output_path = File.join(File.dirname(File.expand_path(__dir__)), 'spec', 'fixtures',
                            "#{dish_name.downcase.gsub(' ', '_')}_ingredients.yml")
    File.open(output_path, 'w') { |file| file.write({ dish_name => ingredients }.to_yaml) }
  end
end

if __FILE__ == $0
  dish_name = ARGV[0] || '蔥油餅'
  MealDecoder.run(dish_name)
end
