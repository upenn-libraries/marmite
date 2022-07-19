require 'sinatra/base'
require 'sinatra/activerecord'
require 'sprockets'

require_relative './base_controller'
require_relative './api/v1_controller'
require_relative './api/v2_controller'

class ApplicationController < BaseController
  use ::Api::V1Controller
  use ::Api::V2Controller

  # Serve up assets
  get "/assets/*" do
    env['PATH_INFO'].sub!('/assets', '')
    logger.error settings.assets.call(env)
    settings.assets.call(env)
  end

  # Render homepage with instructions
  get '/' do
    erb :homepage
  end
end