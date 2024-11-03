# Meal Decoder

Help users to search for different dishes, view ingredients, check for any foods they should avoid, and see calorie information for each dish. This helps users make informed choices and enjoy meals that fit their dietary needs.

## OpenAI API

- Elements
  - dish name
- Entities
  - ingredients
  - calories
  - calorie level

## Google Cloud Vision API

- Elements
  - menu image
- Entities
  - menu text

## Features

- **Decode Ingredients** for any given **Dish name**.
- **Decode Menus Image** to text then select which **Dish name**  you want to **Decode ingredients**.

## Setup

- Copy `config/secrets_example.yml` to `config/secrets.yml` and update token
- Ensure correct version of Ruby install (see `.ruby-version` for `rbenv`)
- Run `bundle install`
- Rub `bundle exec rake db:migrate` to create dev database
- Rub `RACK_ENV=test bundle exec rake db:migrate` to create test database

## Running tests

To run tests:

```shell
rake spec
```
