RSpec.describe 'Application' do
  context 'create_record' do
    context 'marc21' do
      let(:bib_id) { '9951865503503681' }
      let(:record) { Record.new(bib_id: bib_id, format: 'marc21') }
      let(:alma_marc_xml) { File.read(File.join('spec', 'fixtures', 'marc', "#{bib_id}.xml")) }
      let(:expected_xml) { File.read(File.join('spec', 'fixtures', 'blob', 'marc21', "#{bib_id}.xml")) }

      before do
        # Set Alma API key. `create_record` looks for api key in environment variable.
        api_key = 'not_great'
        ENV['ALMA_KEY'] = api_key

        # Mock the Alma API response
        stub_request(
          :get,
          "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{bib_id}&expand=p_avail&apikey=#{api_key}"
        ).to_return(body: alma_marc_xml, headers: { 'Content-Type' => 'application/xml;charset=UTF-8' })

        create_record(record) # calls the method to add blob to Record object
      end

      it "add expected blob xml" do
        expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
      end

      context 'when marc has 650 field, subfield a that begins with PRO' do
        let(:alma_marc_xml) do
          <<~MARC
          <bibs total_record_count="1">
            <bib>
              <record>
                <datafield ind1=" " ind2="0" tag="650">
                  <subfield code="a">PRO Illumination of books and manuscripts, Carolingian</subfield>
                  <subfield code="v">Specimens.</subfield>
                </datafield>
                <datafield ind1=" " ind2="0" tag="650">
                  <subfield code="a">PRO Logic</subfield>
                  <subfield code="v">Early works to 1800.</subfield>
                </datafield>
              </record>
            </bib>
          </bibs>
          MARC
        end

        let(:expected_xml) do
          <<~OUT
            <?xml version="1.0"?>
            <marc:records xmlns:marc="http://www.loc.gov/MARC21/slim" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd">
              <marc:record>
                <marc:datafield ind1=" " ind2=" " tag="561">
              <marc:subfield code="a">Illumination of books and manuscripts, Carolingian</marc:subfield>
            </marc:datafield>
                <marc:datafield ind1=" " ind2=" " tag="561">
              <marc:subfield code="a">Logic</marc:subfield>
            </marc:datafield>
                <marc:datafield ind1=" " ind2="0" tag="650">
              <marc:subfield code="v">Specimens.</marc:subfield>
            </marc:datafield>
                <marc:datafield ind1=" " ind2="0" tag="650">
              <marc:subfield code="v">Early works to 1800.</marc:subfield>
            </marc:datafield>
                <marc:datafield ind1=" " ind2=" " tag="999">
              <marc:subfield code="z">PRO Illumination of books and manuscripts, Carolingian</marc:subfield>
              <marc:subfield code="z">PRO Logic</marc:subfield>
            </marc:datafield>
                <marc:holdings/>
              </marc:record>
            </marc:records>
          OUT
        end

        it "correctly transforms the field to 561" do
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end

      context 'when marc has 650 fields, subfield a that begins with CHR' do
        let(:alma_marc_xml) do
          <<~MARC
          <bibs total_record_count="1">
            <bib>
              <record>
                <datafield ind1=" " ind2="0" tag="650">
                  <subfield code="a">CHR Illumination of books and manuscripts, Carolingian</subfield>
                  <subfield code="v">Specimens.</subfield>
                </datafield>
                <datafield ind1=" " ind2="0" tag="650">
                  <subfield code="a">CHR Logic</subfield>
                  <subfield code="v">Early works to 1800.</subfield>
                </datafield>
              </record>
            </bib>
          </bibs>
          MARC
        end

        let(:expected_xml) do
          <<~OUT
          <?xml version="1.0"?>
          <marc:records xmlns:marc="http://www.loc.gov/MARC21/slim" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd">
            <marc:record>
              <marc:datafield ind1=" " ind2="0" tag="650">
            <marc:subfield code="v">Specimens.</marc:subfield>
          </marc:datafield>
              <marc:datafield ind1=" " ind2="0" tag="650">
            <marc:subfield code="v">Early works to 1800.</marc:subfield>
          </marc:datafield>
              <marc:datafield ind1=" " ind2=" " tag="651">
            <marc:subfield code="y">Illumination of books and manuscripts, Carolingian</marc:subfield>
          </marc:datafield>
              <marc:datafield ind1=" " ind2=" " tag="651">
            <marc:subfield code="y">Logic</marc:subfield>
          </marc:datafield>
              <marc:datafield ind1=" " ind2=" " tag="999">
            <marc:subfield code="z">CHR Illumination of books and manuscripts, Carolingian</marc:subfield>
            <marc:subfield code="z">CHR Logic</marc:subfield>
          </marc:datafield>
              <marc:holdings/>
            </marc:record>
          </marc:records>
          OUT
        end

        it "correctly transforms the field to 651" do
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end

      context 'when marc has INT, INST and AVA fields' do
        it 'they are removed'
      end

      context 'when marc has more than one holdings information' do
        it 'they are both correctly mapped'
      end

      context 'when marc has 710 field, subfield 5' do
        it 'maps subfield a to field 773 subfield t'
      end
    end
  end
end
