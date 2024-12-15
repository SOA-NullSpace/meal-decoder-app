# app/presentation/view_objects/progress_view.rb
# frozen_string_literal: true

module MealDecoder
  # app/presentation/view_objects/progress_view.rb
  module Views
    class Progress
      attr_reader :channel_id

      def initialize(channel_id)
        @channel_id = channel_id
      end

      def faye_endpoint
        "#{App.config.API_HOST}/faye"
      end

      def progress_channel
        "/#{@channel_id}"
      end
    end
  end
end
