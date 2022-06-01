module AlmaApiMocks
  def stub_alma_api_request(bib_id, alma_marc_xml, alma_api_key = '')
    stub_request(
      :get,
      "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{bib_id}&expand=p_avail&apikey=#{alma_api_key}"
    ).to_return(body: alma_marc_xml)
  end

  def stub_alma_api_bib_request(bib_id, alma_marc_xml, alma_api_key = '')
    stub_request(
      :get,
      "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs?expand=p_avail&mms_id=#{bib_id}"
    )
      .with(headers: { 'Authorization' => "apikey #{alma_api_key}" })
      .to_return(status: 200, body: alma_marc_xml)
  end

  def stub_alma_api_bib_not_found
    stub_request(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs?expand=p_avail&mms_id=0000'
    )
      .with(headers: { 'Authorization' => 'apikey ' })
      .to_return(status: 200,
                 body: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><bibs total_record_count="0"/>')
  end

  def stub_alma_api_invalid_xml
    stub_request(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs?expand=p_avail&mms_id=0001'
    )
      .with(headers: { 'Authorization' => 'apikey ' })
      .to_return(status: 200,
                 body: 'this is not valid XML')
  end
end
