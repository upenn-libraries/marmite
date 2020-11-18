RSpec.describe Record, type: :model do
  it 'has class methods' do
    expect(Record).to respond_to :error_message, :error_message=
  end
  it "has instance accessor methods" do
    record = Record.new
    expect(record).to respond_to(
      :bib_id, :format, :blob, :created_at, :updated_at)
  end
  context 'freshness' do
    let(:stale_time) { Time.now - 2.days }
    let(:fresh_time) { Time.now - 1.hour }
    let :stale_marc_record do
      Record.new format: 'marc21', updated_at: stale_time
    end
    let :stale_iiif_record do
      Record.new format: 'iiif_presentation', updated_at: stale_time
    end
    let :fresh_marc_record do
      Record.new format: 'marc21', updated_at: fresh_time
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
  end
end