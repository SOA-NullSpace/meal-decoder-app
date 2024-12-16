# # frozen_string_literal: true

# module MealDecoder
#   module Views
#     # View object for text detection results
#     class TextDetection
#       def initialize(text_result)
#         @text_result = text_result.to_s
#       end

#       def split_dish_names
#         @text_result.split(/[,，\n]/)
#                    .map(&:strip)
#                    .map { |line| clean_dish_name(line) }
#                    .reject { |line| line.empty? || ignore_line?(line) }
#                    .map { |line| format_display_text(line) }
#                    .uniq
#       end

#       def empty?
#         @text_result.empty?
#       end

#       def lines
#         @lines ||= begin
#           dish_lines = @text_result
#                        .split("\n")
#                        .map { |line| clean_dish_name(line) }
#                        .reject(&:empty?)
#                        .reject { |line| ignore_line?(line) }
#                        .map { |line| format_display_text(line) }

#           # If no valid lines found, try split_dish_names as fallback
#           dish_lines.empty? ? split_dish_names : dish_lines
#         end
#       end

#       def each_line_with_index(&)
#         lines.each_with_index(&)
#       end

#       def line_count
#         lines.count
#       end

#       def has_content?
#         line_count.positive?
#       end

#       def each_selectable_line
#         lines.each_with_index do |line, index|
#           clean_value = clean_dish_name(line)
#           yield(
#             id: "text_#{index}",
#             value: clean_value,
#             display_text: format_display_text(clean_value),
#             original_text: line
#           )
#         end
#       end

#       private
#       def call(image_file)
#         validate_file(image_file)
#           .bind { |file| detect_text(file) }
#           .bind { |text| format_text(text) }
#           .bind { |text| { 
#             text: text,
#             channel_id: SecureRandom.uuid  # Add this for progress tracking
#           }}
#       end

#       def clean_dish_name(text)
#         return '' if text.nil?

#         text.strip
#             .gsub(/["'""''』『「」【】]/, '')  # Remove various quote types
#             .gsub(/[（）(){}［］\[\]]/,'')    # Remove various bracket types
#             .gsub(/\(.*?\)/, '')              # Remove parenthetical content
#             .gsub(/（.*?）/, '')              # Remove Chinese parenthetical content
#             .gsub(%r{[/／\\].+$}, '')         # Keep only first part before slashes
#             .gsub(/[,，、;；]/, '')           # Remove separators
#             .gsub(/\s+/, ' ')                 # Normalize whitespace
#             .strip
#       end

#       def format_display_text(line)
#         cleaned = clean_dish_name(line)
#         words = cleaned.split(/\s+/)

#         if contains_cjk?(words.join)
#           # For Asian languages, just clean the text
#           cleaned
#         else
#           # For other languages, capitalize words
#           words.map(&:capitalize).join(' ')
#         end
#       end

#       def contains_cjk?(text)
#         text =~ /\p{Han}|\p{Hiragana}|\p{Katakana}/
#       end

#       def ignore_line?(line)
#         return true if line.nil? || line.empty?

#         cleaned_line = line.strip.downcase

#         ignored_patterns = [
#           /^\d+$/,                     # Only numbers
#           /^[,，、\s]+$/,             # Only separators
#           /^(menu|price|order)$/i,     # Menu headers
#           /^[[:punct:]]+$/,           # Only punctuation
#           /謝謝|please|thank|thank you/i,  # Thank you messages
#           /付款|結帳/,                # Payment related
#           /^cola$/i,                  # Drinks
#           /菜單|價目表/,              # Menu related Chinese text
#           /^\(.*\)$/,                # Only parenthetical content
#           /意麵|油麵|烏龍(?!麵)/      # Noodle types when alone
#         ]

#         ignored_patterns.any? { |pattern| cleaned_line.match?(pattern) }
#       end
#     end
#   end
# end


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
          dish_lines = @text_result
                       .split("\n")
                       .map { |line| clean_dish_name(line) }
                       .reject(&:empty?)
                       .reject { |line| ignore_line?(line) }
                       .map { |line| format_display_text(line) }

          dish_lines.empty? ? split_dish_names : dish_lines
        end
      end

      def line_count
        lines.count
      end

      def has_content?
        line_count.positive?
      end

      def each_selectable_line(&block)
        lines.each_with_index do |line, index|
          clean_value = clean_dish_name(line)
          block.call({
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

        text.strip
            .gsub(/["'""''』『「」【】]/, '')
            .gsub(/[（）(){}［］\[\]]/,'')
            .gsub(/\(.*?\)/, '')
            .gsub(/（.*?）/, '')
            .gsub(%r{[/／\\].+$}, '')
            .gsub(/[,，、;；]/, '')
            .gsub(/\s+/, ' ')
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
        ignored_patterns = [
          /^\d+$/,
          /^[,，、\s]+$/,
          /^(menu|price|order)$/i,
          /^[[:punct:]]+$/,
          /謝謝|please|thank|thank you/i,
          /付款|結帳/,
          /^cola$/i,
          /菜單|價目表/,
          /^\(.*\)$/,
          /意麵|油麵|烏龍(?!麵)/
        ]

        ignored_patterns.any? { |pattern| cleaned_line.match?(pattern) }
      end
    end
  end
end
