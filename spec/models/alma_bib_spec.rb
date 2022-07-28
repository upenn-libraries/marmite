# frozen_string_literal: true

RSpec.describe AlmaBib, type: :model do
  let(:alma_bib) { described_class.new xml }

  context 'with XML including Arabic script' do
    let(:xml) { marc21_pre_transform 'record_with_arabic' }

    it 'is transformed and retains properly encoded Arabic script' do
      expect(alma_bib.transform).to include 'بناني، محمد احمد بن صالح.'
    end
  end
end
