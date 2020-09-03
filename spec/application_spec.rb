require File.expand_path '../spec_helper.rb', __FILE__

RSpec.describe 'Marmite', type: :request do
  it 'works' do
    get '/'
    expect(last_response).to be_ok
  end
end