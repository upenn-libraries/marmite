RSpec.describe 'Homepage', type: :request do
  context 'harvesting information display' do
    it 'shows harvesting endpoints info at /' do
      get '/'
      expect(last_response.body).to include 'Marmite'
      expect(last_response.body).to include 'marc'
    end
  end
end
