require_relative '../base_controller'

class Api
  class V1Controller < BaseController
    # return message to any continued V1 API users, and log to Honybadger
    get '/records*' do
      Honeybadger.notify('Legacy V1 API request')
      [
        303, # see other
        ['Please use Marmite V2 API. ',
         'See <a href="https://gitlab.library.upenn.edu/digital-repository/marmite">the documentation</a>.'].join
      ]
    end
  end
end
