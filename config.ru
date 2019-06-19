require 'sprockets'
require './application'

configure do
  set :protection, :except => [:json_csrf]
end

map '/assets' do
  run Application.assets
end

run Application
