require_relative '../base_controller'

class Api
  class V1Controller < BaseController
    # return message to any continued V1 API users, and log to Honeybadger
    get '/records*' do
      Honeybadger.notify('Legacy V1 API request')
      [303, 'Please use Marmite V2 API. See <a href="/">the documentation</a>.']
    end
  end
end
