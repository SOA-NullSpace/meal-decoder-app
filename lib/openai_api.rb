require 'http'
require 'yaml'

config = YAML.safe_load_file('../config/secrets.yml')

def openai_chat_api_url
  'https://api.openai.com/v1/chat/completions'
end

def call_openai_chat_api(config, dish_name)
  response = HTTP.headers(
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{config['OPENAI_API_KEY']}"
  ).post(openai_chat_api_url, json: {
           model: 'gpt-4o',
           messages: [
             {
               role: 'system',
               content: 'You are a helpful assistant. Please list the ingredients of a dish.'
             },
             {
               role: 'user',
               content: "What are the ingredients in #{dish_name}?"
             }
           ]
         })

  raise "Failed to fetch data from OpenAI: #{response.status} - #{response.body}" unless response.status.success?

  response.parse
end

dish_name = 'လက်ဖက်သုပ်'

begin
  openai_response = call_openai_chat_api(config, dish_name)
  raise 'No choices available in the response.' if openai_response['choices'].nil? || openai_response['choices'].empty?

  ingredients = openai_response['choices'].first['message']['content'].strip
rescue StandardError => e
  puts "Error: #{e}"
  exit
end

results = {
  'dish' => dish_name,
  'ingredients' => ingredients
}

File.write('../spec/fixtures/meal_decoder_results.yml', results.to_yaml)
