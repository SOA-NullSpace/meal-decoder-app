# frozen_string_literal: true

require 'http'
require 'yaml'
require 'delegate'
require 'json' 

module MealDecoder
  module Service
    class IngredientFetcher
      API_URL = 'https://api.openai.com/v1/chat/completions'

      def initialize(api_key)
        @api_key = api_key
      end

      def fetch_ingredients(dish_name)
        response = Request.new(API_URL, @api_key).post_request(dish_name)
        parse_response(response)
      end

      private

      # Handles the API request to OpenAI
      class Request
        def initialize(api_url, api_key)
          @api_url = api_url
          @api_key = api_key
        end

        def post_request(dish_name)
          http_response = HTTP.headers(
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{@api_key}"
          ).post(@api_url, json: request_body(dish_name))

          Response.new(http_response).tap do |response|
            raise(response.error_message) unless response.successful?
          end
        end

        private

        def request_body(dish_name)
          {
            model: 'gpt-4o',
            messages: [
              { role: 'system', content: 'You are a helpful assistant. Please list the ingredients of a dish.' },
              { role: 'user', content: "What are the ingredients in #{dish_name}?" }
            ]
          }
        end
      end

      class Response < SimpleDelegator
        Unauthorized = Class.new(StandardError)
        NotFound = Class.new(StandardError)
        GenericError = Class.new(StandardError)

        HTTP_ERROR = {
          401 => Unauthorized,
          404 => NotFound
        }.freeze

        def successful?
          HTTP_ERROR.keys.none?(code)
        end

        def error_message
          error = HTTP_ERROR[code] || GenericError
          "#{error}: #{self['message'] || body.to_s}"
        end
      end

      def parse_response(response)
        parsed_body = JSON.parse(response.body.to_s)
        parsed_body['choices'].first['message']['content'].strip
      end
    end
  end
end
