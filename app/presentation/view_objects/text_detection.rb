# frozen_string_literal: true

module MealDecoder
  module Views
    # View object for text detection results
    class TextDetection
      def initialize(text_result)
        @text_result = text_result.to_s
        puts "Initializing TextDetection with: #{@text_result}"
      end

      def empty?
        lines.empty?
      end

      def lines
        @lines ||= @text_result
          .split("\n")
          .map(&:strip)
          .reject { |line| line.empty? || line.match?(/[\(\)]/) }  # Remove empty lines and parenthetical content
          .uniq
      end

      def line_count
        lines.count
      end

      def each_selectable_line
        return enum_for(:each_selectable_line) unless block_given?

        lines.each_with_index do |line, index|
          next if line.match?(/[,\.]/) || line.downcase == 'cola'  # Skip lines with punctuation or non-dish items

          yield(
            id: "text_#{index}",
            value: line,
            display_text: format_display_text(line)
          )
        end
      end

      private

      def format_display_text(line)
        line.split(/[\(\)]/).first.strip
      end
    end
  end
end
