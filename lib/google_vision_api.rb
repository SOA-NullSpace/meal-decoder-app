# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'
require 'base64'

module GoogleVisionAPI
  # TextDetector is responsible for detecting text from images
  class TextDetector
    API_KEY = YAML.load_file('config/secrets.yml')['GOOGLE_CLOUD_API_TOKEN']

    def initialize(image)
      @image = image
    end

    def detect_text
      image_content = load_image_content
      request_body = prepare_request_body(image_content)
      response = send_request(request_body)
      process_response(response)
    end

    private

    def load_image_content
      Base64.encode64(@image.read)
    end

    def prepare_request_body(image_content)
      {
        requests: [
          {
            image: { content: image_content },
            features: [{ type: 'TEXT_DETECTION' }]
          }
        ]
      }.to_json
    end

    def send_request(request_body)
      uri = URI('https://vision.googleapis.com/v1/images:annotate')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json', 'X-Goog-Api-Key' => API_KEY })
      request.body = request_body
      http.request(request)
    end

    def process_response(response)
      result = JSON.parse(response.body)
      handle_text_annotations(result['responses'])
    end

    def handle_text_annotations(responses)
      responses.map do |res|
        if res['textAnnotations'].nil? || res['textAnnotations'].empty?
          'No text detected.'
        else
          res['textAnnotations'].map do |text_annotation|
            format_text_annotation(text_annotation)
          end
        end
      end
    end

    def format_text_annotation(text_annotation)
      {
        description: text_annotation['description'],
        bounding_box: text_annotation['boundingPoly']['vertices'].map { |v| "(#{v['x']}, #{v['y']})" }.join(', ')
      }
    end
  end
end
