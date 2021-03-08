module AlmaApiMocks

  def stub_alma_api_request(bib_id, alma_marc_xml, alma_api_key)
    stub_request(
      :get,
      "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{bib_id}&expand=p_avail&apikey=#{alma_api_key}"
    ).to_return(body: alma_marc_xml)
  end

  def stub_alma_api_bib_request(bib_id, alma_marc_xml, alma_api_key)
    stub_request(
      :get,
      'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs?expand=p_avail&mms_id=9951865503503681',
    ).with(headers: { 'Apikey' => '',
                      'Expect' => '',
                      'User-Agent' => 'Typhoeus - https://github.com/typhoeus/typhoeus'} ).
      to_return(status: 200, body: alma_marc_xml)
  end

  # @param [String] body
  def a_successful_response_with(body)
    {
      status: 200,
      body: body,
      headers: { 'Content-Type' => 'application/json' }
    }
  end
end
