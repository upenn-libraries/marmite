RSpec.describe 'Homepage', type: :request do
  context 'harvesting information display' do
    it 'shows harvesting endpoints info at /harvesting' do
      get '/'
      expect(last_response.body).to include 'Harvesting'
    end
  end
end
