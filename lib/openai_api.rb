# frozen_string_literal: true

require 'http'
require 'yaml'
require 'delegate'
require 'json'

module MealDecoder
  module Service
    class IngredientFetcher
      API_URL = 'https://api.openai.com/v1/chat/completions'

      class NotFound < StandardError; end
      class Unauthorized < StandardError; end

      def initialize(api_key)
        @api_key = api_key
      end

      def fetch_ingredients(dish_name)
        response = Request.new(API_URL, @api_key).post_request(dish_name)
        parse_response(response)
      end

      private

      class Request
        def initialize(api_url, api_key)
          @api_url = api_url
          @api_key = api_key
        end

        def post_request(dish_name)
          response = HTTP.headers(
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{@api_key}"
          ).post(@api_url, json: request_body(dish_name))
          Response.new(response)
        end

        def request_body(dish_name)
          {
            model: 'gpt-4o',
            messages: [
              { role: 'system', content: 'You are a helpful assistant. List the ingredients of a dish.' },
              { role: 'user', content: "What are the ingredients in #{dish_name}?" }
            ]
          }
        end
      end

      class Response < SimpleDelegator
        def validate!
          body = JSON.parse(self.body.to_s)
          if body['error']
            raise NotFound, "Dish not found." if body['error']['message'].include?("not found")
            raise Unauthorized, "Invalid API key provided." if body['error']['message'].include?("Invalid API key")
          elsif body['choices'].empty? || body['choices'].first['message']['content'].include?("I'm not sure")
            raise NotFound, "The provided name does not correspond to a known dish."
          end
          body
        end
      end

      def parse_response(response)
        body = response.validate!
        ingredients_text = body['choices'].first['message']['content'].strip

        uncertainty_phrases = [
          "I'm not sure",
          "I'm sorry, but",
          "It seems that there might be",
          "does not appear to be",
          "could you clarify",
          "not familiar with a dish",
          "not widely recognized", "typo in your request", "doesn’t refer to a specific dish"
        ]

        if ingredients_text.empty? ||
           ingredients_text.split(' ').length < 80 ||
           uncertainty_phrases.any? { |phrase| ingredients_text.include?(phrase) }
          raise Service::IngredientFetcher::NotFound, "The provided name does not correspond to a known dish or the description is too vague."
        end

        ingredients_text
      end

    end
  end
end