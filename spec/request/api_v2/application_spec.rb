# frozen_string_literal: true

RSpec.describe 'Marmite V2 API', type: :request do
  include AlmaApiMocks
  include RecordFixtures
  include FixtureHelpers

  describe 'GET /api/v2/record/:bib_id/marc' do
    let(:bib_id) { '9951865503503681' }
    context 'for a new record' do
      before do
        stub_alma_api_bib_request(bib_id,
                                  marc21_pre_transform(bib_id))
      end
      it 'returns a successful response with MARC XML' do
        get "/api/v2/record/#{bib_id}/marc21"
        expect(last_response.status).to eq 201
        expect(last_response.headers).to include('Content-Type' => 'text/xml;charset=utf-8')
        expect(last_response.body).to be_equivalent_to marc21_post_transform(bib_id)
      end
      context 'if bib_id is not found in Alma' do
        before { stub_alma_api_bib_not_found }
        it 'returns 404 and an error response' do
          get '/api/v2/record/0000/marc21'
          expect(last_response.status).to eq 404
          parsed_response = JSON.parse(last_response.body)
          expect(parsed_response['errors'].first).to include '0000'
        end
      end
      context 'with some error in marc processing' do
        before { stub_alma_api_invalid_xml }
        it 'returns a 500 and an error response' do
          get '/api/v2/record/0001/marc21'
          expect(last_response.status).to eq 500
          expect(last_response.headers).to include('Content-Type' => 'application/json')
          expect(JSON.parse(last_response.body)['errors'].first)
            .to include 'MARC transformation error'
        end
      end
    end
    context 'for an existing record' do
      let(:bib) { marc21_record(bib_id) }
      it 'returns a successful response with MARC XML' do
        get "/api/v2/record/#{bib.bib_id}/marc21"
        expect(last_response.status).to eq 200
        expect(last_response.body).to be_equivalent_to marc21_post_transform(bib_id)
      end
      context 'with update params' do
        it 'refreshes the record if update = always and returns a 201' do
          stub_alma_api_bib_request(bib_id,
                                    marc21_pre_transform(bib_id))
          get "/api/v2/record/#{bib.bib_id}/marc21", update: 'always'
          expect(last_response.status).to eq 201
          # expect(last_response.body).to
          # TODO: expect(last_response).to have_some_updated_data
        end
        it 'does not refresh the record if update = never and returns a 200' do
          get "/api/v2/record/#{bib.bib_id}/marc21", update: 'never'
          expect(last_response.status).to eq 200
          # TODO: expect(last_response).to not_have_changed
        end
        it 'refreshes the record if it was created outside of the number of
            hours (ago) specified by the update param' do
          stub_alma_api_bib_request(bib_id,
                                    marc21_pre_transform(bib_id))
          bib.updated_at = Time.now - 24.hours # make bib seem older
          bib.save
          get "/api/v2/record/#{bib.bib_id}/marc21", update: '24'
          expect(last_response.status).to eq 201
          # TODO: expect(last_response).to have_some_updated_data
        end
        it 'does not refresh the record if it was created inside of the number of
            hours (ago) specified by the update param' do
          stub_alma_api_bib_request(bib_id,
                                    marc21_pre_transform(bib_id))
          get "/api/v2/record/#{bib.bib_id}/marc21", update: '12'
          expect(last_response.status).to eq 200
          # TODO: expect(last_response).to not_have_changed
        end
      end
    end
  end
end
