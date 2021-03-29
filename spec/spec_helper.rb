# frozen_string_literal: true

# adapted from http://recipes.sinatrarb.com/p/testing/rspec

require 'rack/test'
require 'rspec'
require 'webmock/rspec'
require 'equivalent-xml/rspec_matchers'
require "rspec/json_expectations"

ENV['RACK_ENV'] = 'test'

require File.expand_path '../application.rb', __dir__
require File.expand_path 'fixtures/record_fixtures', __dir__
require File.expand_path 'support/alma_api_mock', __dir__
require File.expand_path 'support/fixture_helpers', __dir__

module RSpecMixin
  include Rack::Test::Methods
  def app
    Application
  end
end

RSpec.configure do |c|
  c.include RSpecMixin
  c.include RecordFixtures
  c.include AlmaApiMocks

  c.before(:each) do
    Record.destroy_all
  end
end
