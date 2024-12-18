# frozen_string_literal: true

# app/application/services/progress_publisher.rb
module MealDecoder
  module Services
    class ProgressPublisher
      def initialize(config, channel_id)
        @config = config
        @channel_id = channel_id
      end

      def publish(message)
        print "Progress: #{message} "
        print "[post: #{@config.API_HOST}/faye] "

        HTTP.headers(content_type: 'application/json')
            .post(
              "#{@config.API_HOST}/faye",
              json: message_body(message)
            )
            .then { |result| puts "(#{result.status})" }
      rescue HTTP::ConnectionError
        puts '(Faye server not found - progress not sent)'
      end

      private

      def message_body(message)
        {
          channel: "/progress/#{@channel_id}",
          data: message
        }
      end
    end
  end
end
