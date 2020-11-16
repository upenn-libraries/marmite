RSpec.describe Record, type: :model do
  it 'has class methods' do
    expect(Record).to respond_to :error_message, :error_message=
  end
  it "has instance accessor methods" do
    record = Record.new
    expect(record).to respond_to(
      :bib_id, :format, :blob, :created_at, :updated_at)
  end
end