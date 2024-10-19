# frozen_string_literal: true

require 'http'
require 'json'

module MealDecoder
  module Gateways
    class OpenAIAPI
      API_URL = 'https://api.openai.com/v1/chat/completions'

      class UnknownDishError < StandardError; end

      def initialize(api_key)
        @api_key = api_key
        @test_response = nil
      end

      def fetch_ingredients(dish_name)
        response = @test_response || send_request(dish_name)
        ingredients = parse_response(response)

        if unknown_dish?(ingredients)
          raise UnknownDishError, "Unknown dish: #{dish_name}"
        end

        ingredients
      end

      def set_test_response(response)
        @test_response = response
      end

      private

      def send_request(dish_name)
        HTTP.headers(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@api_key}"
        ).post(API_URL, json: request_body(dish_name))
      end

      def request_body(dish_name)
        {
          model: 'gpt-4',
          messages: [
            { role: 'system', content: 'You are a helpful assistant. List the ingredients of a dish.' },
            { role: 'user', content: "What are the ingredients in #{dish_name}?" }
          ]
        }
      end

      def parse_response(response)
        if response.is_a?(String)
          response
        else
          body = JSON.parse(response.body.to_s)

          if body['error']
            handle_error(body['error']['message'])
          elsif body['choices'].empty?
            raise "No response from API"
          else
            body['choices'].first['message']['content'].strip
          end
        end
      end

      def handle_error(message)
        case message
        when /not found/
          raise "Dish not found."
        when /Invalid API key/
          raise "Invalid API key provided."
        else
          raise "API error: #{message}"
        end
      end

      def unknown_dish?(ingredients)
        unknown_phrases = [
          "I'm not sure",
          "I don't have information",
          "I'm not familiar with",
          "I don't know",
          "Unable to provide ingredients",
          "not a recognized dish",
          "doesn't appear to be a specific dish",
          "I don't have enough information",
          "It's unclear what dish you're referring to"
        ]
        unknown_phrases.any? { |phrase| ingredients.downcase.include?(phrase.downcase) }
      end
    end
  end
end
