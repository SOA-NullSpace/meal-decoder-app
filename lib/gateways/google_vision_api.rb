# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'base64'

module MealDecoder
  module Gateways
    # The GoogleVisionAPI class provides methods to interact with the Google Vision API for image analysis.
    class GoogleVisionAPI
      BASE_URL = 'https://vision.googleapis.com/v1/images:annotate'

      def initialize(api_key = ENV.fetch('GOOGLE_CLOUD_API_TOKEN', nil))
        @api_key = api_key
      end

      def detect_text(image_path)
        raise Errno::ENOENT, "File not found: #{image_path}" unless File.exist?(image_path)

        response = send_request(image_path)
        handle_response(response)
      end

      private

      def send_request(image_path)
        uri = build_uri
        request = build_request(uri, image_path)
        perform_request(uri, request)
      end

      def build_uri
        URI.parse("#{BASE_URL}?key=#{@api_key}")
      end

      def build_request(uri, image_path)
        Net::HTTP::Post.new(uri).tap do |request|
          request.content_type = 'application/json'
          request.body = request_body(image_path)
        end
      end

      def perform_request(uri, request)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
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
        return parse_response(response.body) if response.is_a?(Net::HTTPSuccess)

        raise "API request failed with status code: #{response.code}"
      end

      def parse_response(response_body)
        json_response = JSON.parse(response_body)
        text_annotations = json_response.dig('responses', 0, 'textAnnotations')
        text_annotations&.first&.fetch('description', '')&.strip || ''
      end
    end
  end
end
