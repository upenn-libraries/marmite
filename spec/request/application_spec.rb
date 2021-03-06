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
      expect(last_response.body).to include 'Harvesting'
    end
    it 'shows harvesting endpoints info at /records/harvesting' do
      get '/records/harvesting'
      expect(last_response.body).to include 'Harvesting'
    end
  end
  context 'all record display' do
    it 'shows a saved record' do
      record = structural_record
      get '/records'
      expect(last_response.body).to include record.bib_id
    end
  end
  context 'record show' do
    context 'for a structural record' do
      let(:record) { structural_record }
      it 'shows the record info' do
        get "/records/#{record.bib_id}/show", format: :structural
        expect(last_response).to be_ok
        expect(last_response.body).to include(
          BlobHandler.uncompress(record.blob)
        )
      end
    end
    context 'for a IIIF presentation manifest' do
      let(:record) { iiif_presentation_record }
      it 'shows the manifest' do
        get "/records/#{record.bib_id}/show", format: :iiif_presentation
        expect(last_response).to be_ok
        expect(last_response.body).to include(
          BlobHandler.uncompress(record.blob)
        )
      end
    end
  end
  context 'record create' do
    context 'for a IIIF presentation manifest' do
      let(:record) { iiif_presentation_record }
      # TODO: going to take more work to get this working
      xit 'creates and shows the manifest' do
        get "/records/#{record.bib_id}/create", format: :iiif_presentation
        expect(last_response).to be_ok
        expect(last_response.body).to include(
          BlobHandler.uncompress(record.blob)
        )
      end
    end
  end
end
