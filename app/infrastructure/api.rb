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

      # def post(url, data, content_type = :json)
      #   if content_type == :json
      #     result = HTTP.headers(headers)
      #                .post("#{@api_root}/#{url}", json: data)
      #   else
      #     result = HTTP.headers(form_headers)
      #                .post("#{@api_root}/#{url}", form: data)
      #   end
      #   Response.new(result)
      # end
      def post(url, data, content_type = :json)
        result = if content_type == :form
                   HTTP.headers(form_headers)
                     .post("#{@api_root}/#{url}", form: data)
                 else
                   HTTP.headers(headers)
                     .post("#{@api_root}/#{url}", json: data)
                 end
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

    # Response wrapper
    class Response
      attr_reader :status, :message, :payload

      def initialize(http_response)
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
      rescue JSON::ParserError => e
        handle_parse_error(e)
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

      def handle_parse_error(error)
        puts "JSON parsing error: #{error.message}"
        @status = 500
        @message = 'Invalid JSON response from API'
        @payload = nil
      end
    end

    # Main API Gateway class
    class Api
      def initialize(config)
        @config = config
        @request = Request.new(@config)
      end

      def create_dish(name)
        puts "Creating dish with name: #{name}"
        response = @request.post('dishes', { dish_name: name })
        puts "Create dish response: #{response.inspect}"
        response
      end

      def fetch_dish(name)
        puts "Fetching dish with name: #{name}"
        response = @request.get("dishes?q=#{name}")
        puts "Fetch dish response: #{response.inspect}"
        response
      end

      # def detect_text(image_path)
      #   form_data = HTTP::FormData::File.new(image_path)
      #   @request.post('detect_text', { image_file: form_data }, :form)
      # end

      def detect_text(image_path)
        puts "Detecting text from image: #{image_path}"
        process_image_detection(image_path)
      rescue StandardError => e
        log_error_and_return_failure(e)
      end

      private

      def process_image_detection(image_path)
        image_file = File.open(image_path, 'rb')
        form_data = build_form_data(image_file, image_path)
        send_detection_request(form_data)
      ensure
        image_file&.close
      end

      def build_form_data(file, path)
        HTTP::FormData::File.new(
          file,
          content_type: 'image/jpeg',
          filename: File.basename(path)
        )
      end

      def send_detection_request(form_data)
        @request.post('detect_text', { image_file: form_data }, :form)
      end

      def log_error_and_return_failure(error)
        puts "Error in detect_text: #{error.message}"
        puts error.backtrace.join("\n")
        OpenStruct.new(
          success?: false,
          message: "Failed to process image: #{error.message}",
          status: 500
        )
      end
    end
  end
end
