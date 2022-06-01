class BaseController < Sinatra::Base
  # TODO: Figure out logging, currently I don't think its logging errors and we seem to be defining two loggers
  use Rack::Logger
  use Rack::Deflater

  register Sinatra::ActiveRecordExtension

  set :assets, Sprockets::Environment.new
  assets.append_path File.expand_path('../../assets/stylesheets', __FILE__)
  assets.append_path File.expand_path('../../assets/images', __FILE__)

  set :views, File.expand_path('../../views', __FILE__)

  configure do
    set :protection, except: [:json_csrf]
    enable :logging
    use Rack::CommonLogger, STDOUT
  end
end