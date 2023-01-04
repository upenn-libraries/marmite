# frozen_string_literal: true

RSpec.describe AlmaBib, type: :model do
  let(:alma_bib) { described_class.new xml }

  context 'with XML including Arabic script' do
    let(:xml) { marc21_pre_transform 'record_with_arabic' }

    it 'is transformed and retains properly encoded Arabic script' do
      expect(alma_bib.transform).to include 'بناني، محمد احمد بن صالح.'
    end
  end

  context 'with specifically ordered 856 values' do
    let(:xml) { marc21_pre_transform 'record_with_ordered_856' }

    let(:ordered_values) do
      ["Digital facsimile for browsing (Colenda): vol. 3\n  https://colenda.library.upenn.edu/catalog/81431-p3cr5nz85",
       "Digital facsimile for browsing (Colenda): vol. 4\n  https://colenda.library.upenn.edu/catalog/81431-p3r49gw3h",
       "Digital facsimile for browsing (Colenda): vol. 5\n  https://colenda.library.upenn.edu/catalog/81431-p3cn6zk1x",
       "Digital facsimile for browsing (Colenda): vol. 6\n  https://colenda.library.upenn.edu/catalog/81431-p37w67r7j",
       "Digital facsimile for browsing (Colenda): vol. 7\n  https://colenda.library.upenn.edu/catalog/81431-p3445hz46",
       "Digital facsimile for browsing (Colenda): vol. 8\n  https://colenda.library.upenn.edu/catalog/81431-p30g3hj29"]
    end

    it 'retains source ordering' do
      doc = Nokogiri.XML(alma_bib.transform).remove_namespaces!
      elements = doc.search('//record/datafield[@tag="856"]')
      values = elements.collect(&:content).map(&:strip)
      expect(values).to eq ordered_values
    end
  end
end
