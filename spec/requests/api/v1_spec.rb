# frozen_string_literal: true

RSpec.describe 'API V1 requests', type: :request do
  it 'returns a 303' do
    get '/records/12345/show'
    expect(last_response.status).to be 303
  end
end
