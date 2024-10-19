# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'base64'

module MealDecoder
  module Gateways
    class GoogleVisionAPI
      BASE_URL = 'https://vision.googleapis.com/v1/images:annotate'

      def initialize(api_key = nil)
        @api_key = api_key || ENV['GOOGLE_CLOUD_API_TOKEN']
      end

      def detect_text(image_path)
        raise Errno::ENOENT, "File not found: #{image_path}" unless File.exist?(image_path)

        response = send_request(image_path)
        handle_response(response)
      end

      private

      def send_request(image_path)
        uri = URI.parse("#{BASE_URL}?key=#{@api_key}")
        request = Net::HTTP::Post.new(uri)
        request.content_type = 'application/json'
        request.body = request_body(image_path)

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end

      def request_body(image_path)
        JSON.dump(
          requests: [{
            image: {
              content: Base64.strict_encode64(File.read(image_path))
            },
            features: [{
              type: 'TEXT_DETECTION'
            }]
          }]
        )
      end

      def handle_response(response)
        case response
        when Net::HTTPSuccess
          parse_response(response.body)
        when Net::HTTPUnauthorized, Net::HTTPForbidden
          raise "API request failed with status code: #{response.code}"
        when Net::HTTPNotFound
          raise "Resource not found."
        else
          raise "API request failed with status code: #{response.code}"
        end
      end

      def parse_response(response_body)
        json_response = JSON.parse(response_body)
        text_annotations = json_response.dig('responses', 0, 'textAnnotations')

        if text_annotations && !text_annotations.empty?
          text_annotations[0]['description'].strip
        else
          ''
        end
      end
    end
  end
end
