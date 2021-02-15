RSpec.describe 'Application' do
  let(:alma_api_key) { 'not_a_valid_key' }

  before do
    # Set Alma API key. `create_record` looks for api key in environment variable.
    ENV['ALMA_KEY'] = alma_api_key
  end

  after do
    ENV['ALMA_KEY'] = ''
  end

  context 'create_record' do
    context 'marc21' do
      let(:record) { Record.new(bib_id: bib_id, format: 'marc21') }
      let(:bib_id) { '9951865503503681' }

      before do
        # Mock the Alma API response
        stub_request(
            :get,
            "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{bib_id}&expand=p_avail&apikey=#{alma_api_key}"
        ).to_return(body: alma_marc_xml, headers: {'Content-Type' => 'application/xml;charset=UTF-8'})

        create_record(record) # calls the method to add blob to Record object
      end

      context 'when entire marc record is provided' do
        let(:alma_marc_xml) { File.read(File.join('spec', 'fixtures', 'pre_transformation', 'marc', "#{bib_id}.xml")) }
        let(:expected_xml) { File.read(File.join('spec', 'fixtures', 'post_transformation', 'marc21', "#{bib_id}.xml")) }

        it "add expected blob xml" do
        end
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
        let(:alma_marc_xml) do
          <<~MARC
            <bibs total_record_count="1">
              <bib>
                <record>
                  <datafield ind1=" " ind2="0" tag="INT">
                  </datafield>
                  <datafield ind1=" " ind2="0" tag="INST">
                  </datafield>
                  <datafield ind1=" " ind2="0" tag="AVA">
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
                <marc:holdings/>
              </marc:record>
            </marc:records>
          OUT
        end
        it 'they are removed' do
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end

      context 'when marc has more than one holdings information' do
        let(:alma_marc_xml) do
          <<~MARC
            <bibs total_record_count="1">
              <bib>
                <record>
                   <datafield ind1=" " ind2=" " tag="AVA">
                      <subfield code="0">9951865503503681</subfield>
                      <subfield code="8">22335156650003681</subfield>
                      <subfield code="a">01UPENN_INST</subfield>
                      <subfield code="b">KislakCntr</subfield>
                      <subfield code="c">Manuscripts</subfield>
                      <subfield code="d">LJS 101</subfield>
                      <subfield code="e">available</subfield>
                      <subfield code="f">1</subfield>
                      <subfield code="g">0</subfield>
                      <subfield code="j">scmss</subfield>
                      <subfield code="k">8</subfield>
                      <subfield code="p">1</subfield>
                      <subfield code="q">Kislak Center for Special Collections, Rare Books and Manuscripts</subfield>
                   </datafield>
                   <datafield ind1=" " ind2=" " tag="AVA">
                      <subfield code="0">9951865503503682</subfield>
                      <subfield code="8">22335156650003682</subfield>
                      <subfield code="a">01UPENN_INST</subfield>
                      <subfield code="b">KislakCntr</subfield>
                      <subfield code="c">Manuscripts</subfield>
                      <subfield code="d">LJS 202</subfield>
                      <subfield code="e">available</subfield>
                      <subfield code="f">1</subfield>
                      <subfield code="g">0</subfield>
                      <subfield code="j">scmss</subfield>
                      <subfield code="k">8</subfield>
                      <subfield code="p">1</subfield>
                      <subfield code="q">Kislak Center for Special Collections, Rare Books and Manuscripts</subfield>
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
                <marc:holdings>
                  <marc:holding>
                    <marc:holding_id>22335156650003681</marc:holding_id>
                    <marc:call_number>LJS 101</marc:call_number>
                    <marc:library>KislakCntr</marc:library>
                    <marc:location>scmss</marc:location>
                  </marc:holding>
                  <marc:holding>
                    <marc:holding_id>22335156650003682</marc:holding_id>
                    <marc:call_number>LJS 202</marc:call_number>
                    <marc:library>KislakCntr</marc:library>
                    <marc:location>scmss</marc:location>
                  </marc:holding>
                </marc:holdings>
              </marc:record>
            </marc:records>
          OUT
        end
        it 'they are both correctly mapped' do
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end

      context 'when marc has 710 field, subfield 5' do
        let(:alma_marc_xml) do
          <<~MARC
            <bibs total_record_count="1">
              <bib>
                <record>
                  <datafield ind1="2" ind2=" " tag="710">
                    <subfield code="a">Saint-Benoît-sur-Loire (Abbey),</subfield>
                    <subfield code="e">former owner.</subfield>
                    <subfield code="5">TEST</subfield>
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
                <marc:datafield ind1="2" ind2=" " tag="710">
              <marc:subfield code="a">Saint-Benoi&#x302;t-sur-Loire (Abbey),</marc:subfield>
              <marc:subfield code="e">former owner.</marc:subfield>
              <marc:subfield code="5">TEST</marc:subfield>
            </marc:datafield>
                <marc:datafield ind1="0" ind2="0" tag="773">
              <marc:subfield code="t">Saint-Benoi&#x302;t-sur-Loire (Abbey),</marc:subfield>
            </marc:datafield>
                <marc:holdings/>
              </marc:record>
            </marc:records>
          OUT
        end
        it 'maps subfield a to field 773 subfield t' do
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end
    end

    context 'structural' do
      context 'when bib is 7 numbers' do
        let(:bib_id) { '5968339' }
        let(:record) { Record.new(bib_id: bib_id, format: 'structural') }
        let(:structural_xml) { File.read(File.join('spec', 'fixtures', 'pre_transformation', 'structural', "#{bib_id}.xml")) }
        let(:expected_xml) { File.read(File.join('spec', 'fixtures', 'post_transformation', 'structural', "#{bib_id}.xml")) }

        before do
          # Mock the response from the service hosted on mgibney's dev machine.
          stub_request(
              :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{bib_id}.xml"
          ).to_return(body: structural_xml, headers: {'Content-Type' => 'text/xml; charset=UTF-8'})
        end

        it 'adds expected blob xml to record' do
          create_record(record) # calls the method to add blob to Record object
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end

      context 'when bib is greater than 7 numbers and structural is not found' do
        before do
          stub_request(
              :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{long_bib_id}.xml"
          ).to_return(body: '<?xml version="1.0" encoding="UTF-8"?><integ:root xmlns:integ="http://integrator"/>', headers: {'Content-Type' => 'text/xml; charset=UTF-8'})
          stub_request(
              :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{short_bib_id}.xml"
          ).to_return(body: structural_xml, headers: {'Content-Type' => 'text/xml; charset=UTF-8'})
        end

        let(:short_bib_id) { '5968339' }
        let(:long_bib_id) { "99#{short_bib_id}3503681" }
        let(:record) { Record.new(bib_id: long_bib_id, format: 'structural') }
        let(:structural_xml) { File.read(File.join('spec', 'fixtures', 'pre_transformation', 'structural', "#{short_bib_id}.xml")) }
        let(:expected_xml) { File.read(File.join('spec', 'fixtures', 'post_transformation', 'structural', "#{long_bib_id}.xml")) }

        it 'adds expected blob xml to record' do
          create_record(record)
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end

      context 'when structural contains toc data' do
        let(:bib_id) { '4952127' }
        let(:record) { Record.new(bib_id: bib_id, format: 'structural') }
        let(:expected_xml) { File.read(File.join('spec', 'fixtures', 'post_transformation', 'structural', "#{bib_id}.xml")) }
        let(:structural_xml) { File.read(File.join('spec', 'fixtures', 'pre_transformation', 'structural', "#{bib_id}.xml"))}

        before do
          stub_request(
              :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{bib_id}.xml"
          ).to_return(body: structural_xml, headers: {'Content-Type' => 'text/xml; charset=UTF-8'})
        end

        it 'adds expected bob xml to record' do
          create_record(record)
          expect(BlobHandler.uncompress(record.blob)).to eq expected_xml
        end
      end
    end

    context 'openn' do
      let(:record) { Record.new(bib_id: bib_id, format: 'openn') }
      let(:bib_id) { '5968339' }
      let(:long_bib_id) { "99#{bib_id}3503681" }
      let(:alma_marc_xml) { File.read(File.join('spec', 'fixtures', 'pre_transformation', 'marc', "#{bib_id}.xml")) }
      let(:structural_xml) { File.read(File.join('spec', 'fixtures', 'pre_transformation', 'structural', "#{bib_id}.xml")) }
      let(:expected_xml) { File.read(File.join('spec', 'fixtures', 'post_transformation', 'openn', "#{bib_id}.xml")) }

      before do
        # Mock request to Alma API that returns MARC
        stub_request(
            :get,
            "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{long_bib_id}&expand=p_avail&apikey=#{alma_api_key}"
        ).to_return(body: alma_marc_xml, headers: {'Content-Type' => 'application/xml;charset=UTF-8'})

        # Mock the response from the service hosted on mgibney's dev machine that returns structural metadata
        stub_request(
            :get, "http://mgibney-dev.library.upenn.int:8084/lookup/#{bib_id}.xml"
        ).to_return(body: structural_xml, headers: {'Content-Type' => 'text/xml; charset=UTF-8'})
      end

      it 'add expected blob xml to record containing both structural and marc data' do
        create_record(record)
        expect(BlobHandler.uncompress(record.blob)).to be_equivalent_to(expected_xml)
      end
    end

    context 'iiif_presentation' do
      let(:record) { Record.new(bib_id: identifier, format: 'iiif_presentation') }
      let(:identifier) { '81431-p36q1sp1f' }
      let(:colenda_response) do
        File.read(File.join('spec', 'fixtures', 'pre_transformation', 'iiif_presentation', "#{identifier}.json"))
      end
      let(:expected_iiif_manifest) do
        File.read(File.join('spec', 'fixtures', 'post_transformation', 'iiif_presentation', "#{identifier}.json"))
      end

      before do
        endpoint_prefix = 'https://colenda.library.upenn.edu/repos'
        endpoint_suffix = 'fetch_image_ids'
        phalt = 'https://colenda.library.upenn.edu/phalt'
        ENV['IMAGE_ID_ENDPOINT_PREFIX'] = endpoint_prefix
        ENV['IMAGE_ID_ENDPOINT_SUFFIX'] = endpoint_suffix
        ENV['IIIF_SERVER'] = phalt

        # Mocking Colenda response
        stub_request(:get, "#{endpoint_prefix}/#{identifier}/#{endpoint_suffix}").to_return(body: colenda_response)

        # Mocking Phalt requests
        stub_request(:get, /#{Regexp.escape(phalt)}/).to_return(body: '{ "width": 3500, "height": 6250, "profile": ["http://iiif.io/api/image/2/level2.json"] }')
      end

      after do
        ENV['IMAGE_ID_ENDPOINT_PREFIX'] = ''
        ENV['IMAGE_ID_ENDPOINT_SUFFIX'] = ''
        ENV['IIIF_SERVER'] = ''
      end

      it 'adds expected iiif presentation manifest to record' do
        create_record(record)
        expect(JSON.parse(BlobHandler.uncompress(record.blob))).to eql(JSON.parse(expected_iiif_manifest))
      end
    end
  end
end
