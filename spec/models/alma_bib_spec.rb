# frozen_string_literal: true

RSpec.describe AlmaBib, type: :model do
  let(:alma_bib) { described_class.new xml }

  describe '#transform' do
    let(:transformed_xml) { Nokogiri.XML(alma_bib.transform).remove_namespaces! }

    context 'when 650$a with prefixes are present' do
      let(:xml) { marc21_pre_transform 'record_with_prefixed_650a' }

      # This ensures that the parent nodes are removed.
      it 'removes all prefixed 650 fields with a prefixed $a' do
        expect(transformed_xml.xpath('//record/datafield[@tag="650"]').count).to be 4
      end
    end

    context 'when 650$a starting with `CHR` is present' do
      let(:xml) { marc21_pre_transform 'record_with_prefixed_650a' }

      it 'removes value in 650$a that are prefixed with CHR' do
        elements = transformed_xml.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]')
        values = elements.collect(&:content)

        expect(values.select { |v| v.start_with?('CHR ') }).to be_blank
      end
    end

    context 'when 650$a starting with `PRO` is present' do
      let(:xml) { marc21_pre_transform 'record_with_prefixed_650a' }

      it 'removes values in 650$a prefixed with PRO' do
        elements = transformed_xml.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]')
        values = elements.collect(&:content)

        expect(values.select { |v| v.start_with?('PRO ') }).to be_blank
      end

      it 'moves values to 561$a' do
        elements = transformed_xml.xpath('//record/datafield[@tag="561"]/subfield[@code="a"]')
        values = elements.collect(&:content)

        expect(values).to include('Smith, Edgar Fahs, 1854-1928 (autograph, 1917)', 'Wright, H. (autograph, 1870)')
      end
    end

    context 'when Penn collection name is present in 710$a' do
      let(:xml) { marc21_pre_transform 'record_with_collection_name_in_710' }

      it 'removes the value from 710$a' do
        expect(transformed_xml.xpath('//record/datafield[@tag="710"]').count).to be 1
      end

      it 'moves value to 773$t' do
        elements = transformed_xml.xpath('//record/datafield[@tag="773"]/subfield[@code="t"]')
        values = elements.collect(&:content)

        expect(values).to include('University of Pennsylvania Medical Dissertation Digital Library.')
      end
    end

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
        elements = transformed_xml.search('//record/datafield[@tag="856"]')
        values = elements.collect(&:content).map(&:strip)
        expect(values).to eq ordered_values
      end
    end
  end
end
