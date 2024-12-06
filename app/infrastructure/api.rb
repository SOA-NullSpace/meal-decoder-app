# frozen_string_literal: true

require 'http'

module MealDecoder
  module Gateway
    # HTTP request handling
    class Request
      def initialize(config)
        @api_host = config.API_HOST
        @api_root = "#{@api_host}/api/v1"
      end

      def get(url)
        result = HTTP.headers(headers).get("#{@api_root}/#{url}")
        Response.new(result)
      end

      def post_json(url, data)
        result = HTTP.headers(headers)
          .post("#{@api_root}/#{url}", json: data)
        Response.new(result)
      end

      def post_form(url, data)
        result = HTTP.headers(form_headers)
          .post("#{@api_root}/#{url}", form: data)
        Response.new(result)
      end

      private

      def headers
        {
          'Accept'       => 'application/json',
          'Content-Type' => 'application/json'
        }
      end

      def form_headers
        {
          'Accept' => 'application/json'
        }
      end
    end

    # Response wrapper for HTTP responses
    class Response
      attr_reader :status, :message, :payload

      def initialize(http_response)
        process_response(http_response)
      end

      def success?
        [200, 201].include?(@status)
      end

      private

      def process_response(response)
        case response
        when HTTP::Response
          @status = response.code
          if response.status.success?
            process_successful_response(response)
          else
            process_error_response(response)
          end
        end
      rescue JSON::ParserError => e
        handle_parse_error(e)
      end

      def process_successful_response(response)
        body = JSON.parse(response.body.to_s)
        @message = body['message']
        @payload = body
      end

      def process_error_response(response)
        @message = "API Error: #{response.status}"
        @payload = nil
      end

      def handle_parse_error(error)
        @status = 500
        @message = "Invalid JSON response: #{error.message}"
        @payload = nil
      end
    end

    # Main API Gateway class
    class Api
      # Creates properly formatted multipart form data objects for API requests
      class FormData
        def self.create(file, path)
          HTTP::FormData::File.new(
            file,
            content_type: 'image/jpeg',
            filename: File.basename(path)
          )
        end
      end

      def initialize(config)
        @config = config
        @request = Request.new(@config)
      end

      def create_dish(name)
        puts "Creating dish with name: #{name}"
        response = @request.post_json('dishes', { dish_name: name })
        puts "API Response: #{response.inspect}"
        response
      end

      def fetch_dish(name)
        puts "Fetching dish with name: #{name}"
        response = @request.get("dishes?q=#{name}")
        puts "Fetch dish response: #{response.inspect}"
        handle_response(response)
      end

      def detect_text(image_path)
        puts "Detecting text from image: #{image_path}"
        process_image_detection(image_path)
      rescue StandardError => error
        handle_detection_error(error)
      end

      private

      def handle_response(response)
        return response if response.success?

        # Enhanced error handling
        OpenStruct.new(
          success?: false,
          message: response.message || 'API request failed',
          payload: nil
        )
      end

      def process_image_detection(image_path)
        image_file = File.open(image_path, 'rb')
        form_data = FormData.create(image_file, image_path)
        @request.post_form('detect_text', { image_file: form_data })
      ensure
        image_file&.close
      end

      def handle_detection_error(error)
        error_message = error.message
        puts "Error in detect_text: #{error_message}"
        puts error.backtrace.join("\n")

        OpenStruct.new(
          success?: false,
          message: "Failed to process image: #{error_message}",
          status: 500
        )
      end
    end
  end
end
