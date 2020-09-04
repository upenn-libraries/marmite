require File.expand_path '../../spec_helper.rb', __FILE__

RSpec.describe 'Marmite', type: :request do
  context 'supported formats display' do
    let :all_formats do
      Application::AVAILABLE_FORMATS
    end
    it 'shows formats at /formats' do
      get '/formats'
      expect(last_response.body).to include *all_formats
    end
    it 'shows formats at /available_formats' do
      get '/available_formats'
      expect(last_response.body).to include *all_formats
    end
    it 'shows formats at /records/formats' do
      get '/records/formats'
      expect(last_response.body).to include *all_formats
    end
  end
  context 'supported image id prefixes display' do
    let :all_image_id_prefixes do
      Application::IMAGE_ID_PREFIXES
    end
    it 'shows prefixes at /image_id_prefixes' do
      get '/image_id_prefixes'
      expect(last_response.body).to include *all_image_id_prefixes
    end
    it 'shows prefixes at /records/image_id_prefixes/' do
      get '/records/image_id_prefixes/'
      expect(last_response.body).to include *all_image_id_prefixes
    end
  end
  context 'harvesting information display' do
    it 'shows harvesting endpoints info at /harvesting' do
      get '/harvesting'
      expect(last_response.body).to include 'Harvesting', 'Rake Tasks'
    end
    it 'shows harvesting endpoints info at /records/harvesting' do
      get '/records/harvesting'
      expect(last_response.body).to include 'Harvesting', 'Rake Tasks'
    end
  end
end