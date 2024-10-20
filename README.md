# Meal Decoder

Application that allows **users** to understand the **ingredients** of various **dishes** and **menus**, enhancing dietary safety and personalization.

## Overview

Meal Decoder will utilize OpenAI's API for dish analysis and Google Cloud Vision API for image recognition of menus.

It will then generate **ingredient lists** and **dietary information** for specific dishes. We call this a **decoding** process: users should feel empowered to understand the components of their meals.

We hope this tool will give users a clear understanding of what's in their food, but also provide insights into potential dietary concerns. We do not want our decoding to be the sole basis for dietary decisions. Instead, we intend our ingredient reports to be the beginning of a conversation between users and food providers, and among individuals with dietary restrictions. It is up to users to make informed decisions based on the information provided and their personal health needs.

## How It Works

1. Users can input a **dish name** or upload a **menu image**.
2. For text inputs, the system uses the OpenAI API to **decode** the dish and generate an **ingredient list**.
3. For image inputs, the Google Cloud Vision API extracts text, which is then processed to identify dish names.
4. The system then provides a detailed breakdown of the dish, including its likely ingredients and any potential dietary concerns.

## Objectives

### Short-term usability goals

- Extract dish information from OpenAI API
- Analyze menu images using Google Cloud Vision API
- Display comprehensive ingredient lists for dishes
- **Dish** (A specific food item or recipe)
- **Ingredients** (Components used in preparing a dish)

### Long-term goals

- Implement user profiles for personalized dietary restrictions
- Develop a mobile app for on-the-go menu decoding
- Integrate with restaurant APIs for real-time menu analysis

## Setup

- Create API access tokens for OpenAI and Google Cloud Vision
- Copy `config/secrets_example.yml` to `config/secrets.yml` and update tokens
- Ensure correct version of Ruby is installed (see `.ruby-version` for `rbenv`)
- Run `bundle install`

## Running tests

To run tests:

```shell
rake spec
```
