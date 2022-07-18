# frozen_string_literal: true

RSpec.describe StructuralMetadataService do
  let(:empty_source_xml) { fixture_contents('post_transformation', 'structural', 'empty.xml') }
  let(:long_bib_id) { "99#{short_bib_id}3503681" }

  subject(:produced_xml) { StructuralMetadataService.new(long_bib_id).fetch_and_transform }

  context '#fetch_and_transform' do
    context 'when structural is not found' do
      let(:short_bib_id) { '1234567' }

      before do
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{long_bib_id}.xml"
        ).to_return(body: empty_source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{short_bib_id}.xml"
        ).to_return(body: empty_source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })
      end

      it 'returns nil' do
        expect(produced_xml).to be_nil
      end
    end

    context 'when structural for long bibnumber is not found' do
      let(:short_bib_id) { '5968339' }
      let(:source_xml) { fixture_contents('pre_transformation', 'structural', "#{short_bib_id}.xml") }
      let(:expected_xml) {fixture_contents('post_transformation', 'structural', "#{long_bib_id}.xml") }

      before do
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{long_bib_id}.xml"
        ).to_return(body: empty_source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{short_bib_id}.xml"
        ).to_return(body: source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })
      end

      it 'returns expected xml' do
        expect(produced_xml).to be_equivalent_to expected_xml
      end
    end

    context 'when structural includes toc data' do
      let(:short_bib_id) { '4952127' }
      let(:source_xml) { fixture_contents('pre_transformation', 'structural', "#{short_bib_id}.xml") }
      let(:expected_xml)  {fixture_contents('post_transformation', 'structural', "#{long_bib_id}.xml") }

      before do
        stub_request(
          :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{long_bib_id}.xml"
        ).to_return(body: source_xml, headers: { 'Content-Type' => 'text/xml; charset=UTF-8' })
      end

      it 'returns expected xml' do
        expect(produced_xml).to be_equivalent_to expected_xml
      end
    end
  end
end