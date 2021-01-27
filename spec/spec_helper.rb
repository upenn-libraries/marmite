# adapted from http://recipes.sinatrarb.com/p/testing/rspec

require 'rack/test'
require 'rspec'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

require File.expand_path '../../application.rb', __FILE__
require File.expand_path '../fixtures/record_fixtures', __FILE__

module RSpecMixin
  include Rack::Test::Methods
  def app
    Application
  end
end

RSpec.configure do |c|
  c.include RSpecMixin
  c.include RecordFixtures

  c.before(:each) do
    Record.destroy_all
  end
end
