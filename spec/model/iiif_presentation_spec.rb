RSpec.describe IIIFPresentation do
  context '#new' do
    context 'when missing title' do
      it 'returns error' do
        expect {
          described_class.new(id: 'item-1', sequence: [{ label: 'Image 1' }], image_server: 'https://example.com/iiif/2')
        }.to raise_error(IIIFPresentation::MissingArgument, 'Missing title')
      end
    end

    context 'when missing id' do
      it 'returns error' do
        expect {
          described_class.new('title' => 'New Item', 'sequence' => [{ label: 'Image 1' }], 'image_server' => 'https://example.com/iiif/2')
        }.to raise_error(IIIFPresentation::MissingArgument, 'Missing id')
      end
    end

    context 'when missing image_server' do
      it 'returns error' do
        expect {
          described_class.new(id: 'item-1', title: 'New Item', sequence: [{ label: 'Image 1' }])
        }.to raise_error(IIIFPresentation::MissingArgument, 'Missing image_server')
      end
    end
    context 'when empty sequence' do
      it 'returns error' do
        expect {
          described_class.new(id: 'item-1', title: 'New Item', image_server: 'https://example.com/iiif/2')
        }.to raise_error(IIIFPresentation::MissingArgument, 'Missing sequence')
      end
    end
  end

  context '#generate' do
    # Mocking image server requests.
    before do
      stub_request(:get, /#{Regexp.escape(data['image_server'])}/)
        .to_return(body: '{ "width": 3500, "height": 4596, "profile": ["http://iiif.io/api/image/2/level2.json"] }')
    end

    context 'when body contains table of contents for some assets' do
      let(:data) { JSON.parse(fixture_contents('pre_transformation', 'iiif_presentation', 'with_table_of_contents.json')) }
      let(:expected_manifest) { JSON.parse(fixture_contents('post_transformation', 'iiif_presentation', 'with_table_of_contents.json')) }

      it 'generates expected iiif presentation manifest' do
        expect(described_class.new(data).manifest).to include_json(expected_manifest)
      end
    end

    context 'when body contains labels for each assets' do
      let(:data) { JSON.parse(fixture_contents('pre_transformation', 'iiif_presentation', 'with_labels.json')) }
      let(:expected_manifest) { JSON.parse(fixture_contents('post_transformation', 'iiif_presentation', 'with_labels.json')) }

      it 'generates expected iiif presentation manifest' do
        expect(described_class.new(data).manifest).to include_json(expected_manifest)
      end
    end


    context 'when body does not contain table of contents or labels for any assets' do
      let(:data) { JSON.parse(fixture_contents('pre_transformation', 'iiif_presentation', 'without_labels.json')) }
      let(:expected_manifest) { JSON.parse(fixture_contents('post_transformation', 'iiif_presentation', 'without_labels.json')) }

      it 'generates expected iiif presentation manifest' do
        expect(described_class.new(data).manifest).to include_json(expected_manifest)
      end
    end
  end
end
