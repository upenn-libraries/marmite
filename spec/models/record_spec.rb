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
      described_class.create bib_id: '1234567890123456'
      described_class.create bib_id: '123456'
    end

    it 'removes only short bib records' do
      described_class.purge_all_short_bibs
      expect(described_class.find_by(bib_id: '1234567890123456')).not_to be_nil
      expect(described_class.find_by(bib_id: '1234567')).to be_nil
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
