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
        @status = nil
        @message = nil
        @payload = nil
        @response = http_response
        parse_response
      end

      def success?
        [200, 201].include?(@status)
      end

      private

      def parse_response
        case @response
        when HTTP::Response
          process_http_response
        end
      rescue JSON::ParserError => parse_error
        handle_parse_error(parse_error)
      end

      def process_http_response
        puts "Raw response body: #{@response.body}"
        if @response.status.success?
          process_successful_response
        else
          process_error_response
        end
      end

      def process_successful_response
        body = JSON.parse(@response.body.to_s)
        @status = @response.code
        @message = body['message']
        @payload = body
        puts "Parsed response payload: #{@payload}"
      end

      def process_error_response
        @status = @response.code
        @message = "API Error: #{@response.status}"
        @payload = nil
        puts "API Error response: #{@message}"
      end

      def handle_parse_error(parse_error)
        puts "JSON parsing error: #{parse_error.message}"
        @status = 500
        @message = 'Invalid JSON response from API'
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
        puts "Create dish response: #{response.inspect}"
        response
      end

      def fetch_dish(name)
        puts "Fetching dish with name: #{name}"
        response = @request.get("dishes?q=#{name}")
        puts "Fetch dish response: #{response.inspect}"
        response
      end

      def detect_text(image_path)
        puts "Detecting text from image: #{image_path}"
        process_image_detection(image_path)
      rescue StandardError => error
        handle_detection_error(error)
      end

      private

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
