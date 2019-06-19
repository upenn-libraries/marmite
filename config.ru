require 'sprockets'
require './application'

map '/assets' do
  run Application.assets
end

run Application
