# frozen_string_literal: true

RSpec.describe 'API V2 IIIF Presentation Requests', type: :request do
  describe 'GET /api/v2/records/:id/iiif_presentation' do
    context 'when record is not present' do
      before { get '/api/v2/records/invalid/iiif_presentation' }

      it 'returns 404' do
        expect(last_response.status).to be 404
      end

      it 'returns error' do
        expect(last_response.body).to include_json({ errors: ["Record not found."] })
      end
    end

    context 'when a record is present' do
      # Mock requests
      let(:id) { '81431-p36q1sp1f' }
      let(:data) { JSON.parse(fixture_contents('pre_transformation', 'iiif_presentation', 'without_labels.json')) }
      let(:expected_manifest) { JSON.parse(fixture_contents('post_transformation', 'iiif_presentation', 'without_labels.json')) }

      before do
        stub_request(:get, /#{Regexp.escape(data['image_server'])}/)
          .to_return(body: '{ "width": 3500, "height": 4596, "profile": ["http://iiif.io/api/image/2/level2.json"] }')
        Record.new(bib_id: id, format: Record::IIIF_PRESENTATION).set_blob(data)
        get "/api/v2/records/#{id}/iiif_presentation"
      end

      it 'returns 200' do
        expect(last_response.status).to be 200
      end

      it 'returns IIIF presentation manifest' do
        expect(last_response.body).to include_json(expected_manifest)
      end
    end
  end

  describe 'POST /api/v2/records/:id/iiif_presentation' do
    context 'when creating record with complete post data' do
      let(:id) { '81431-p36q1sp1f' }
      let(:data) { JSON.parse(fixture_contents('pre_transformation', 'iiif_presentation', 'without_labels.json')) }
      let(:expected_manifest) { JSON.parse(fixture_contents('post_transformation', 'iiif_presentation', 'without_labels.json')) }

      before do
        stub_request(:get, /#{Regexp.escape(data['image_server'])}/)
          .to_return(body: '{ "width": 3500, "height": 4596, "profile": ["http://iiif.io/api/image/2/level2.json"] }')
        post "/api/v2/records/#{id}/iiif_presentation", data.to_json
      end

      it 'creates record' do
        expect(Record.find_by(bib_id: id, format: Record::IIIF_PRESENTATION).uncompressed_blob).to include_json(expected_manifest)
      end

      it 'returns 201' do
        expect(last_response.status).to be 201
      end

      it 'returns IIIF presentation manifest' do
        expect(last_response.body).to include_json(expected_manifest)
      end
    end

    context 'when creating record without partial post data' do
      let(:id) { '1234' }
      before { post "/api/v2/records/#{id}/iiif_presentation", '{ "id": "#{id}" }' }

      it 'does not create record' do
        expect(Record.find_by(bib_id: id, format: Record::IIIF_PRESENTATION)).to be_nil
      end

      it 'returns 500' do
        expect(last_response.status).to be 500
      end

      it 'returns error' do
        expect(last_response.body).to include_json({ errors: ["Unexpected error generating IIIF manifest."] })
      end
    end
  end
end
