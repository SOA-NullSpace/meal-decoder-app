# frozen_string_literal: true

module MealDecoder
  module Views
    # Handles text formatting operations for display purposes
    class TextFormatter
      def self.format_display_text(line)
        line.split.map(&:capitalize).join(' ')
      end
    end

    # Manages text detection results and processing
    class TextDetection
      def initialize(text_result)
        @text_result = text_result.to_s
      end

      def empty?
        lines.empty?
      end

      def lines
        @lines ||= @text_result
          .split("\n")
          .map(&:strip)
          .reject { |line| line.empty? || line.match?(/[\(\)]/) }
          .uniq
      end

      def line_count
        lines.count
      end

      def each_selectable_line
        return enum_for(:each_selectable_line) unless block_given?

        lines.each_with_index do |line, index|
          next if line.match?(/[,\.]/) || line.downcase == 'cola'

          yield(
            id: "text_#{index}",
            value: line,
            display_text: TextFormatter.format_display_text(line)
          )
        end
      end
    end
  end
end
