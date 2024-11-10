module MealDecoder
  module Views
    # View object that encapsulates presentation logic for a dish entity
    # Handles conversion of dish data for display, including calorie calculations
    # and formatting ingredient information
    class Dish
      attr_reader :id, :name

      def initialize(entity)
        @entity = entity
        @id = entity.id
        @name = entity.name
      end

      def ingredients
        @entity.ingredients.map do |ingredient|
          ingredient.is_a?(String) ? StringIngredient.new(ingredient) : ingredient
        end
      end

      def has_ingredients?
        @entity.ingredients&.any?
      end

      def ingredients_count
        @entity.ingredients&.size || 0
      end

      def total_calories
        @entity.total_calories
      end

      def calorie_class
        case total_calories
        when 0..500 then 'success'
        when 501..800 then 'warning'
        else 'danger'
        end
      end

      def calorie_level
        case total_calories
        when 0..400 then 'Low Calorie'
        when 401..700 then 'Medium Calorie'
        else 'High Calorie'
        end
      end
    end

    # Handles string-based ingredients
    class StringIngredient
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def display_calories
        "#{calories} cal"
      end

      def calories
        MealDecoder::Lib::NutritionCalculator.get_calories(name)
      end

      def to_s
        name
      end
    end

    # Handles object-based ingredients
    class Ingredient
      attr_reader :name, :amount, :unit

      def initialize(entity)
        @entity = entity
        @name = entity.name
        @amount = entity.amount
        @unit = entity.unit
      end

      def display_calories
        "#{calories} cal"
      end

      def calories
        MealDecoder::Lib::NutritionCalculator.get_calories(@name)
      end

      def to_s
        if @amount && @unit
          "#{@amount} #{@unit} #{@name}"
        else
          @name
        end
      end
    end
  end
end
