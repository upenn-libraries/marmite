require 'sinatra/custom_logger'
require 'logger'

class BaseController < Sinatra::Base
  helpers Sinatra::CustomLogger

  use Rack::Deflater

  register Sinatra::ActiveRecordExtension

  set :assets, Sprockets::Environment.new
  assets.append_path File.expand_path('../../assets/stylesheets', __FILE__)
  assets.append_path File.expand_path('../../assets/images', __FILE__)

  set :views, File.expand_path('../../views', __FILE__)

  configure do
    set :protection, except: [:json_csrf]
    set :logger, Logger.new(STDOUT)
  end
end