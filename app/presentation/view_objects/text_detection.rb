# frozen_string_literal: true

module MealDecoder
  module Views
    class TextDetection
      def initialize(text_result)
        @text_result = text_result.to_s
      end

      def split_dish_names
        @text_result.split(/[,，\n]/)
                   .map(&:strip)
                   .map { |line| clean_dish_name(line) }
                   .reject { |line| line.empty? || ignore_line?(line) }
                   .map { |line| format_display_text(line) }
                   .uniq
      end

      def empty?
        @text_result.empty?
      end

      def lines
        @lines ||= begin
          # Enhanced line parsing for better detection
          raw_lines = @text_result.split(/\n|,|;|\r/).map(&:strip)

          # Remove prices and other non-dish text
          dish_lines = raw_lines.map do |line|
            next if line.empty? || ignore_line?(line)

            # Cleaning up the dish name more comprehensively
            clean_line = line.gsub(/\$\d+(\.\d{2})?/, '').strip
            clean_dish_name(clean_line)
          end.compact

          dish_lines.uniq.reject(&:empty?)
        end
      end

      def line_count
        lines.count
      end

      def has_content?
        line_count.positive?
      end

      def each_selectable_line
        lines.each_with_index do |line, index|
          clean_value = clean_dish_name(line)
          yield({
            id: "dish_#{index}",
            value: clean_value,
            display_text: format_display_text(clean_value),
            original_text: line
          })
        end
      end

      private

      def clean_dish_name(text)
        return '' if text.nil?

        # Remove unwanted characters and normalize whitespace
        text.strip
            .gsub(/["'""''』『「」【】]/, '')
            .gsub(/[\d"'\/\\,.:;(){}\[\]]+/, '')
            .gsub(/[（）(){}［］\[\]]/, '')
            .gsub(/\(.*?\)/, '')
            .gsub(/（.*?）/, '')
            .gsub(%r{[/／\\].+$}, '')
            .gsub(/[,，、;；]/, '')
            .gsub(/\s+/, ' ')
            .gsub(/\s+-\s+/, ' ')
            .strip
      end

      def format_display_text(line)
        cleaned = clean_dish_name(line)
        words = cleaned.split(/\s+/)

        if contains_cjk?(words.join)
          cleaned
        else
          words.map(&:capitalize).join(' ')
        end
      end

      def contains_cjk?(text)
        text =~ /\p{Han}|\p{Hiragana}|\p{Katakana}/
      end

      def ignore_line?(line)
        return true if line.nil? || line.empty?

        cleaned_line = line.strip.downcase

        # Update ignored patterns to capture more irrelevant lines
        ignored_patterns = [
          /^\d+$/,
          /^[,，、\s]+$/,
          /^(menu|price|order)$/i,
          /^[[:punct:]]+$/,
          /thank you/i,
          /付款|結帳/,
          /^cola$/i,
          /菜單|價目表/,
          /^\(.*\)$/
        ]

        ignored_patterns.any? { |pattern| cleaned_line.match?(pattern) }
      end
    end
  end
end
