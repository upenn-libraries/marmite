# frozen_string_literal: true

RSpec.describe 'API V2 Structural Requests', type: :request do
  describe 'GET /api/v2/records/:bib_id/structural' do
    let(:long_bib_id) { "99#{short_bib_id}3503681" }

    context 'when record is not present in Marmite' do
      let(:short_bib_id) { '123456' }

      before { get "/api/v2/records/#{short_bib_id}/structural" }

      it 'does not create record' do
        expect(Record.count).to be 0
      end

      it 'returns 404' do
        expect(last_response.status).to be 404
      end

      it 'returns correct content type' do
        expect(last_response.content_type).to eql 'application/json'
      end

      it 'returns error' do
        expect(JSON.parse(last_response.body)['errors'].first).to include 'Record not found.'
      end
    end

    context 'when record is present' do
      before { get "/api/v2/records/#{record.bib_id}/structural" }

      context 'with no structural metadata' do
        let(:record) { create(:structural_record, :without_pages) }

        it 'returns 404' do
          expect(last_response.status).to be 404
        end

        it 'returns correct content type' do
          expect(last_response.content_type).to eql 'application/json'
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

        it 'returns correct content type' do
          expect(last_response.content_type).to eql 'text/xml;charset=utf-8'
        end

        it 'returns expected xml' do
          expect(last_response.body).to be_equivalent_to expected_xml
        end
      end
    end
  end
end