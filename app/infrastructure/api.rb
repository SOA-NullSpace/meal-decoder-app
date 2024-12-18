# app/infrastructure/api.rb
require 'http'

module MealDecoder
  module Gateway
    class Api
      def initialize(config)
        @config = config
        @request = Request.new(@config)
      end

      def create_dish(name)
        puts "Creating dish with name: #{name}"
        begin
          response = @request.post('dishes', {
                                     dish_name: name.strip
                                   })

          case response.status
          when 201, 202
            Response.new(response)
          else
            puts "Error creating dish: #{response.status} - #{response.message}"
            OpenStruct.new(
              success?: false,
              message: response.message || 'Failed to create dish',
              status: response.status
            )
          end
        rescue StandardError => e
          puts "Exception in create_dish: #{e.message}"
          puts e.backtrace
          OpenStruct.new(
            success?: false,
            message: "Service error: #{e.message}",
            status: 500
          )
        end
      end

      def fetch_dish(name_or_id)
        puts "Fetching dish: #{name_or_id}"
        begin
          # If it's a name, use the search endpoint
          endpoint = name_or_id.is_a?(Integer) ? "dishes/#{name_or_id}" : "dishes?q=#{CGI.escape(name_or_id.to_s)}"
          response = @request.get(endpoint)

          parsed_response = Response.new(response)

          if parsed_response.success?
            # If we got a list of dishes, find the matching one
            if parsed_response.payload['recent_dishes']
              dish = parsed_response.payload['recent_dishes'].find do |d|
                d['name'].downcase == name_or_id.to_s.downcase || d['id'].to_s == name_or_id.to_s
              end

              if dish
                return OpenStruct.new(
                  success?: true,
                  payload: dish,
                  message: 'Dish found',
                  status: 200
                )
              end
            end

            # If we got a single dish directly
            if parsed_response.payload['name']
              return OpenStruct.new(
                success?: true,
                payload: parsed_response.payload,
                message: 'Dish found',
                status: 200
              )
            end
          end

          OpenStruct.new(
            success?: false,
            message: 'Dish not found',
            status: 404
          )
        rescue StandardError => e
          puts "Error fetching dish: #{e.message}"
          puts e.backtrace
          OpenStruct.new(
            success?: false,
            message: "Failed to fetch dish: #{e.message}",
            status: 500
          )
        end
      end

      def detect_text(image_path)
        puts "Starting text detection for image: #{image_path}"

        unless File.exist?(image_path)
          puts "Image file not found: #{image_path}"
          return OpenStruct.new(
            success?: false,
            message: 'Image file not found',
            status: 404,
            payload: nil
          )
        end

        begin
          # Create form data with the image file
          form_data = {
            'image_file' => HTTP::FormData::File.new(
              image_path,
              filename: File.basename(image_path),
              content_type: 'image/jpeg'
            )
          }

          # Send request to your API service
          response = HTTP.post(
            "#{@config.API_HOST}/api/v1/detect_text",
            form: form_data
          )

          if response.status.success?
            body = JSON.parse(response.body.to_s)
            OpenStruct.new(
              success?: true,
              message: body['message'] || 'Text detected successfully',
              status: response.status.code,
              payload: body
            )
          else
            OpenStruct.new(
              success?: false,
              message: "API error: #{response.status.reason}",
              status: response.status.code,
              payload: nil
            )
          end
        rescue StandardError => e
          puts "Text detection error: #{e.class} - #{e.message}"
          puts e.backtrace

          OpenStruct.new(
            success?: false,
            message: "Failed to detect text: #{e.message}",
            status: 500,
            payload: nil
          )
        end
      end

      private

      def log_response(response)
        puts "API Response Status: #{response.status}"
        puts "API Response Body: #{response.body}"
      rescue StandardError => e
        puts "Error logging response: #{e.message}"
      end
    end

    class Request
      def initialize(config)
        @api_host = config.API_HOST
        @api_root = "#{@api_host}/api/v1"
      end

      def get(url)
        HTTP.headers(headers).get("#{@api_root}/#{url}")
      end

      def post(url, data)
        HTTP.headers(headers)
            .post("#{@api_root}/#{url}", json: data)
      rescue HTTP::Error => e
        puts "HTTP Error in post request: #{e.message}"
        raise
      end

      private

      def headers
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      end
    end

    class Response
      attr_reader :status, :message, :payload

      def initialize(http_response)
        @response = http_response
        parse_response
      end

      def success?
        [200, 201, 202].include?(@status)
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
  end
end
