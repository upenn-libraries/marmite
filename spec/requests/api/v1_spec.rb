RSpec.describe 'API V1 requests', type: :request do
  context 'record show' do
    context 'for a structural record' do
      let(:record) { create(:structural_record) }

      it 'shows the record info' do
        get "/records/#{record.bib_id}/show", format: :structural
        expect(last_response).to be_ok
        expect(last_response.body).to include(BlobHandler.uncompress(record.blob))
      end
    end

    context 'for a IIIF presentation manifest' do
      let(:record) { create(:iiif_record) }

      it 'shows the manifest' do
        get "/records/#{record.bib_id}/show", format: :iiif_presentation
        expect(last_response).to be_ok
        expect(last_response.body).to include(BlobHandler.uncompress(record.blob))
      end
    end
  end

  context 'record create' do
    context 'for a IIIF presentation manifest' do
      let(:record) { create(:iiif_record) }
      # TODO: going to take more work to get this working
      xit 'creates and shows the manifest' do
        get "/records/#{record.bib_id}/create", format: :iiif_presentation
        expect(last_response).to be_ok
        expect(last_response.body).to include(BlobHandler.uncompress(record.blob))
      end
    end
  end
end
