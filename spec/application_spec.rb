RSpec.describe 'Application' do
  context 'create_record' do
    context 'marc21' do
      let(:bib_id) { '9951865503503681' }
      let(:record) { Record.new(bib_id: bib_id, format: 'marc21') }
      let(:alma_marc_xml) { File.read(File.join('spec', 'fixtures', 'marc', "#{bib_id}.xml")) }
      let(:expected_xml) { '' } # fixture

      before do
        # mock api response
        api_key = 'not_great'
        ENV['ALMA_KEY'] = 'not_great'

        stub_request(
          :get,
          "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{bib_id}&expand=p_avail&apikey=#{api_key}"
        ).to_return(body: alma_marc_xml, headers: { 'Content-Type' => 'application/xml;charset=UTF-8' })

        create_record(record)
      end


      it "add expected blob xml" do
        expect(BlobHandler.uncompress(record.blob)).to be eql expected_xml
      end
    end
  end
end
