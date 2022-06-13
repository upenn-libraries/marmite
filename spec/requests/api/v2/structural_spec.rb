# frozen_string_literal: true

RSpec.describe 'API V2 Structural Requests', type: :request do
  describe 'GET /api/v2/records/:bib_id/structural' do
    let(:long_bib_id) { "99#{short_bib_id}3503681" }

    context 'when record is not present in Marmite' do
      before do
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{long_bib_id}.xml"
        ).to_return(body: source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{short_bib_id}.xml"
        ).to_return(body: source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })

        get "/api/v2/records/#{short_bib_id}/structural"
      end

      context 'when metadata is available from remote source' do
        let(:short_bib_id) { '5968339' }
        let(:source_xml) { fixture_contents('pre_transformation', 'structural', "#{short_bib_id}.xml") }
        let(:expected_xml) { fixture_contents('post_transformation', 'structural', "#{long_bib_id}.xml") }

        it 'creates a record' do
          expect(Record.find_by(bib_id: long_bib_id, format: 'structural')).not_to be nil
        end

        it 'returns 201' do
          expect(last_response.status).to be 201
        end

        it 'returns expected xml' do
          expect(last_response.body).to be_equivalent_to expected_xml
        end
      end

      context 'when metadata is not available from remote source' do
        let(:short_bib_id) { '123456' }
        let(:source_xml) { fixture_contents('pre_transformation', 'structural',  'empty.xml') }
        let(:expected_xml) { fixture_contents('post_transformation', 'structural', 'empty.xml') }

        it 'does not create record' do
          expect(Record.count).to be 0
        end

        it 'returns 404' do
          expect(last_response.status).to be 404
        end

        it 'returns error' do
          expect(JSON.parse(last_response.body)['errors'].first).to include 'Record not found.'
        end
      end
    end

    context 'when record is present' do
      before { get "/api/v2/records/#{record.bib_id}/structural" }

      context 'with no structural metadata' do
        let(:record) { create(:structural_record, :without_pages) }

        it 'returns 404' do
          expect(last_response.status).to be 404
        end

        it 'returns errors' do
          expect(JSON.parse(last_response.body)['errors'].first).to include 'Record not found.'
        end
      end

      context 'with structural metadata' do
        let(:record) { create(:structural_record, :with_pages) }
        let(:expected_xml) { fixture_contents('post_transformation', 'structural', '9959683393503681.xml') }

        it 'returns 200' do
          expect(last_response.status).to be 200
        end

        it 'returns expected xml' do
          expect(last_response.body).to be_equivalent_to expected_xml
        end
      end
    end
  end
end