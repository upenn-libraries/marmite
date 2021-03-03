module AlmaApiMocks

  def stub_alma_api_request(bib_id, alma_marc_xml, alma_api_key)
    stub_request(
      :get,
      "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/?mms_id=#{bib_id}&expand=p_avail&apikey=#{alma_api_key}"
    ).to_return(body: alma_marc_xml, headers: {'Content-Type' => 'application/xml;charset=UTF-8'})
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
