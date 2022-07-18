# frozen_string_literal: true

# Adapted from https://github.com/sinatra/sinatra-recipes/blob/master/testing/rspec.md

require 'rack/test'
require 'rspec'
require 'factory_bot'
require 'webmock/rspec'
require 'equivalent-xml/rspec_matchers'
require 'rspec/json_expectations'
require 'pry'

ENV['RACK_ENV'] = 'test'

require File.expand_path '../app/controllers/application_controller', __dir__

# Loading helper classes
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

# Only allow localhost connections when running tests.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include FactoryBot::Syntax::Methods
  config.include FixtureHelpers
  config.include AlmaApiMocks

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:each) do
    Record.destroy_all
  end

  def app
    ApplicationController
  end
end
