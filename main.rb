# frozen_string_literal: true

require 'faraday'
require 'dotenv'
require 'json'

Dotenv.load

def fetch_new_tokens_from_fitbit
  conn = Faraday.new(
    url: 'https://api.fitbit.com/oauth2/token',
    params: { grant_type: 'refresh_token',
              refresh_token: ENV['FITBIT_REFRESH_TOKEN'] },
    headers: { 'Authorization' => "Basic #{ENV['FITBIT_BASIC_TOKEN']}",
               'Content-Type' => 'application/x-www-form-urlencoded',
               'Accept' => 'application/json' }
  )
  response = conn.post
  raise "Failed to feth new token from fitbit: #{response.status}" if response.status != 200

  body = JSON.parse(response.body)
  raise 'Failed to get access_token from response_body' unless body['access_token']
  raise 'Failed to get refresh_token from response_body' unless body['refresh_token']

  [body['access_token'], body['refresh_token']]
end

def update_local_dotenv_file(new_refresh_token)
  p 'start updating localhost dotenv'
  buffer = File.open('.env', 'r') { |f| f.read }
  buffer.gsub!(/FITBIT_REFRESH_TOKEN=.+/, "FITBIT_REFRESH_TOKEN=#{new_refresh_token}")
  File.open('.env', 'w') { |f| f.write(buffer) }
  p 'update localhost dotenv ended'
end

def fetch_steps_from_fitbit(access_token)
  conn = Faraday.new(
    url: 'https://api.fitbit.com/1/user/-/activities/steps/date/today/7d.json',
    headers: { 'Authorization' => "Bearer #{access_token}",
               'Accept' => 'application/json' }
  )
  response = conn.get
  raise "Failed to feth steps from fitbit: #{response.status}" if response.status != 200

  body = JSON.parse(response.body)
  raise "Failed to get steps data: #{body}" unless body['activities-steps']

  body['activities-steps']
end

def put_steps_to_pixela(steps)
  p steps
  conn = Faraday.new(
    url: ENV['PIXELA_GRAPH_URL'],
    headers: { 'X-USER-TOKEN' => ENV['PIXELA_BASIC_TOKEN'],
               'Content-Type' => 'application/json' }
  )
  response = conn.post do |connection|
    connection.body = { "date": steps['dateTime'].gsub('-', ''), "quantity": steps['value'] }.to_json
  end

  raise "Failed to put steps to pixela: #{response.status}" if response.status != 200
end

access_token, refresh_token = fetch_new_tokens_from_fitbit
p 'get tokens sucessfully'

update_local_dotenv_file(refresh_token)

step_list = fetch_steps_from_fitbit(access_token)

step_list.each do |steps|
  put_steps_to_pixela(steps)
end

p 'put steps to pixela successfully'
