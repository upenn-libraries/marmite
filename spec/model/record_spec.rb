require File.expand_path '../../spec_helper.rb', __FILE__

RSpec.describe Record, type: :model do
  it 'has class methods' do
    expect(Record).to respond_to :error_message, :error_message=
  end
  # TODO: need to establish expectations for a testing MySQL instance before these can run properly
  xit "has instance accessor methods" do
    record = Record.new
    expect(record).to respond_to(
      :bib_id, :format, :blob, :created_at, :updated_at)
  end
end