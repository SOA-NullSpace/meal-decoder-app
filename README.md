# Meal Decoder

To search for dishes, view possible ingredients, to let users find out the things they cannot eat, and enhance safety and personalization for dietary needs.

## OpenAI API

- Elements
  - dish name
- Entities
  - description
  - ingredients

## Google Cloud Vision API

- Elements
  - image file
- Entities
  - text from image

## Features

- **Fetch** ingredients for any given **dish** from openai api.
- **Parse** and **display** recipes in a user-friendly format.
- Utilize advanced APIs such as Google Vision for extracting dish names from **menus** and OpenAI for retrieving **ingredients**.

## Components

- **Dish**: Represents the food item with its name and required ingredients.
- **IngredientFetcher**: Interfaces with OpenAI to **fetch** and **parse** ingredients.
- **DishMapper**: Parse data fetched by the **IngredientFetcher** into output **ingredients** ymal file.
