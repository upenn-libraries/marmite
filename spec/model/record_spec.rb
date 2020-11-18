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
    it 'returns false if not an always recreated type' do
      record = Record.new(
        format: 'marc21',
        updated_at: Time.now - 1.hour
      )
      expect(record.fresh?).to eq false
    end
    it 'returns true if an always recreated type' do
      record = Record.new(
        format: 'structural_ark',
        updated_at: Time.now - 1.hour
      )
      expect(record.fresh?).to eq true
    end
    it 'returns false if more than one day old' do
      record = Record.new(
        format: 'marc21',
        updated_at: Time.now - 2.days
      )
      expect(record.fresh?).to eq false
    end
    it 'returns true if less than one day old' do
      record = Record.new(
        format: 'marc21',
        updated_at: Time.now - 1.hour
      )
      expect(record.fresh?).to eq false
    end
  end
end