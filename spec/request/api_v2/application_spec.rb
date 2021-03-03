RSpec.describe 'Marmite V2 API', type: :request do
  include AlmaApiMocks

  describe 'GET /api/v2/record/:bib_id/marc' do
    before do
      stub_alma_api_request bib_id, alma_marc_xml, alma_api_key
    end
    context 'for a new record'do
      # TODO: stub alma api request
      let(:bib_id) { '9951865503503681' }
      let(:alma_api_key) { '' }
      let(:alma_marc_xml) do
        File.read(File.join('spec', 'fixtures', 'pre_transformation', 'marc', "#{bib_id}.xml"))
      end
      it 'returns a successful response with MARC XML' do
        get "/api/v2/record/#{bib_id}/marc21"
        expect(last_response.code).to eq '201'
        # TODO: expect(last_response).to be_marc_xml
      end
      context 'if bib_id is not found in Alma' do
        it 'returns 404 and an error response' do
          get "/api/v2/record/0000/marc"
          expect(last_response.code).to eq '404'
          # TODO: expect(last_response).to be_a_json_error_object
        end
      end
      context 'with some error in marc processing' do
        it 'returns a 500 and an error response' do
          get "/api/v2/record/0001/marc"
          expect(last_response.code).to eq '500'
          # TODO: expect(last_response).to be_a_json_error_object
        end
      end
    end
    context 'for an existing record' do
      let(:bib) do
        # TODO: Record.new(format: :marc) or some fixture
      end
      it 'returns a successful response with MARC XML' do
        get "/api/v2/record/#{bib.bib_id}/marc"
        expect(last_response.code).to eq '200'
        # TODO: expect(last_response).to be_marc_xml
      end
      context 'with update params' do
        it 'refreshes the record if update = always and returns a 201' do
          get "/api/v2/record/#{bib.bib_id}/marc", update: 'always'
          expect(last_response.code).to eq '201'
          # TODO: expect(last_response).to have_some_updated_data
        end
        it 'does not refresh the record if update = never and returns a 200' do
          get "/api/v2/record/#{bib.bib_id}/marc", update: 'never'
          expect(last_response.code).to eq '200'
          # TODO: expect(last_response).to not_have_changed
        end
        it 'refreshes the record if it was created outside of the number of
            hours (ago) specified by the update param' do
          get "/api/v2/record/#{bib.bib_id}/marc", update: '24'
          expect(last_response.code).to eq '201'
          # TODO: expect(last_response).to have_some_updated_data
        end
        it 'does not refresh the record if it was created inside of the number of
            hours (ago) specified by the update param' do
          get "/api/v2/record/#{bib.bib_id}/marc", update: '12'
          expect(last_response.code).to eq '200'
          # TODO: expect(last_response).to not_have_changed
        end
      end
    end
  end
end
