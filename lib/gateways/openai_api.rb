# frozen_string_literal: true

require 'http'
require 'json'

module MealDecoder
  module Gateways
    # The OpenAIAPI class is responsible for interfacing with the OpenAI API to fetch ingredients for dishes.
    class OpenAIAPI
      API_URL = 'https://api.openai.com/v1/chat/completions'

      class UnknownDishError < StandardError; end

      # Initializes the OpenAIAPI with an API key.
      def initialize(api_key)
        @api_key = api_key
        @test_response = nil
      end

      # Fetches ingredients for a given dish name using the OpenAI API or a test response if set.
      def fetch_ingredients(dish_name)
        response = @test_response || send_request(dish_name)
        ingredients = parse_response(response)
        raise UnknownDishError, "Unknown dish: #{dish_name}" if unknown_dish?(ingredients)

        ingredients
      end

      # Sets a test response to be used instead of sending a real API request.
      attr_writer :test_response

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
        body = response.is_a?(String) ? parse_string_response(response) : parse_http_response(response)
        handle_response_errors(body) if body['error']
        body['choices'].first['message']['content'].strip
      end

      def parse_string_response(response)
        JSON.parse(response)
      end

      def parse_http_response(response)
        JSON.parse(response.body.to_s)
      end

      def handle_response_errors(body)
        message = body['error']['message']
        raise 'Dish not found.' if message =~ /not found/
        raise 'Invalid API key provided.' if message =~ /Invalid API key/

        raise "API error: #{message}"
      end

      def unknown_dish?(ingredients)
        unknown_phrases = [
          "I'm not sure", "I don't have information", "I'm not familiar with",
          "I don't know", 'Unable to provide ingredients', 'not a recognized dish',
          "doesn't appear to be a specific dish", "I don't have enough information",
          "It's unclear what dish you're referring to"
        ]
        unknown_phrases.any? { |phrase| ingredients.downcase.include?(phrase.downcase) }
      end
    end
  end
end
