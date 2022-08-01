RSpec.describe Record, type: :model do
  it 'has class methods' do
    expect(described_class).to respond_to :error_message, :error_message=
  end

  it "has instance accessor methods" do
    record = described_class.new
    expect(record).to respond_to(
      :bib_id, :format, :blob, :created_at, :updated_at)
  end

  context 'short bib purge' do
    before do
      described_class.create bib_id: '1234567890123456', format: 'marc21'
      described_class.create bib_id: '123456', format: 'marc21'
      described_class.create bib_id: 'blah-123456', format: 'iiif_presentation'
      described_class.create bib_id: '01000', format: 'openn'
      described_class.purge_all_short_bibs
    end

    it 'removes only short bib records' do
      expect(described_class.exists?(bib_id: '1234567890123456', format: 'marc21')).to be true
      expect(described_class.exists?(bib_id: '123456', format: 'marc21')).to be false
    end

    it 'leave records not having marc21 or structural format values' do
      expect(described_class.exists?(bib_id: 'blah-123456', format: 'iiif_presentation')).to be true
      expect(described_class.exists?(bib_id: '01000')).to be true
    end
  end

  context 'freshness' do
    let(:stale_time) { Time.now - 2.days }
    let(:fresh_time) { Time.now - 1.hour }
    let :stale_marc_record do
      described_class.new format: 'marc21', updated_at: stale_time
    end
    let :stale_iiif_record do
      described_class.new format: 'iiif_presentation', updated_at: stale_time
    end
    let :fresh_marc_record do
      described_class.new format: 'marc21', updated_at: fresh_time
    end
    let :fresh_iiif_record do
      described_class.new format: 'iiif_presentation', updated_at: fresh_time
    end
    it 'returns false if stale and not an always recreated type' do
      expect(stale_marc_record.fresh?).to eq false
    end
    it 'returns false if stale and an always recreated type' do
      expect(stale_iiif_record.fresh?).to eq false
    end
    it 'returns true if fresh and not an always recreated type' do
      expect(fresh_marc_record.fresh?).to eq true
    end
    # Record::FORMATS_TO_ALWAYS_RECREATE format records are never considered fresh
    it 'returns false if fresh and an always recreated type' do
      expect(fresh_iiif_record.fresh?).to eq false
    end
  end
end
