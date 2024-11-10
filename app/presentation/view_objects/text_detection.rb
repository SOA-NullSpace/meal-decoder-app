module MealDecoder
  module Views
    # View object for text detection results
    class TextDetection
      def initialize(text_result)
        @text_result = text_result.to_s
      end

      def empty?
        @text_result.empty?
      end

      def lines
        @lines ||= @text_result
                   .split("\n")
                   .map(&:strip)
                   .reject(&:empty?)
      end

      def each_line_with_index(&)
        lines.each_with_index(&)
      end

      def line_count
        lines.count
      end

      def has_content?
        line_count.positive?
      end

      def each_selectable_line
        lines.each_with_index do |line, index|
          yield(
            id: "text_#{index}",
            value: line,
            display_text: TextDetection.format_display_text(line)
          )
        end
      end

      def self.format_display_text(line)
        # Add any text formatting logic here
        # For example, capitalizing first letter of each word
        line.split.map(&:capitalize).join(' ')
      end
    end
  end
end
