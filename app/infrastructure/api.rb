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
          process_by_status(response)
        end
      rescue JSON::ParserError => parse_error
        handle_parse_error(parse_error.message)
      end

      def process_by_status(response)
        if response.status.success?
          process_successful_response(response)
        else
          process_error_response(response)
        end
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

      def handle_parse_error(error_message)
        @status = 500
        @message = "Invalid JSON response from API: #{error_message}"
        @payload = nil
      end
    end

    # Handles API response processing and error transformation
    class ResponseHandler
      def self.handle_response(response)
        return response if response.success?

        OpenStruct.new(
          success?: false,
          message: response.message || 'API request failed',
          payload: nil
        )
      end
    end

    # Handles image processing errors
    class ErrorHandler
      def self.handle_detection_error(error_message)
        OpenStruct.new(
          success?: false,
          message: "Failed to process image: #{error_message}",
          status: 500
        )
      end
    end

    # Handles creating standardized error responses for API failures
    class ErrorResponse
      def self.create(error_message)
        OpenStruct.new(
          success?: false,
          message: "Failed to process image: #{error_message}",
          status: 500
        )
      end
    end

    # Creates form data for image file uploads
    class FormDataCreator
      def initialize(file, path)
        @file = file
        @path = path
        @content_type = 'image/jpeg'
      end

      def create
        HTTP::FormData::File.new(
          @file,
          filename: filename,
          content_type: @content_type
        )
      end

      private

      def filename
        File.basename(@path)
      end
    end

    # Handles image file upload operations including form data creation
    class ImageUploader
      def initialize(request, creator_class: FormDataCreator)
        @request = request
        @creator_class = creator_class
      end

      def upload(image_path)
        image_file = File.open(image_path, 'rb')
        form_data = create_form_data(image_file, image_path)
        @request.post_form('detect_text', { image_file: form_data })
      ensure
        image_file&.close
      end

      private

      def create_form_data(file, path)
        @creator_class.new(file, path).create
      end
    end

    # Main API Gateway handling all external service requests
    class Api
      def initialize(config)
        @config = config
        @request = Request.new(@config)
      end

      def create_dish(name)
        puts "Creating dish with name: #{name}"
        @request.post_json('dishes', { dish_name: name })
      end

      def fetch_dish(name)
        puts "Fetching dish with name: #{name}"
        @request.get("dishes?q=#{name}")
      end

      def detect_text(image_path)
        puts "Detecting text from image: #{image_path}"
        uploader = ImageUploader.new(@request)
        uploader.upload(image_path)
      rescue StandardError => error
        ErrorResponse.create(error.message)
      end
    end
  end
end
