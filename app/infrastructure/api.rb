# app/infrastructure/gateways/api.rb
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
          'Accept' => 'application/json',
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
          puts "Raw response body: #{@response.body}"
          if @response.status.success?
            body = JSON.parse(@response.body.to_s)
            @status = @response.code
            @message = body['message']
            @payload = body
            puts "Parsed response payload: #{@payload}"
          else
            @status = @response.code
            @message = "API Error: #{@response.status}"
            @payload = nil
            puts "API Error response: #{@message}"
          end
        end
      rescue JSON::ParserError => e
        puts "JSON parsing error: #{e.message}"
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
        begin
          # Create form data with proper content type and filename
          image_file = File.open(image_path, 'rb')
          form_data = HTTP::FormData::File.new(
            image_file,
            content_type: 'image/jpeg', # Adjust based on actual file type
            filename: File.basename(image_path)
          )

          # Build proper multipart form data
          form = {
            image_file: form_data
          }

          response = @request.post('detect_text', form, :form)
          puts "Image upload response: #{response.inspect}"
          response
        rescue StandardError => e
          puts "Error in detect_text: #{e.message}"
          puts e.backtrace.join("\n")
          OpenStruct.new(
            success?: false,
            message: "Failed to process image: #{e.message}",
            status: 500
          )
        ensure
          image_file&.close
        end
      end
    end
  end
end
