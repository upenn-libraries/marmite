# frozen_string_literal: true

require 'faraday'
require 'faraday/net_http'

# Wrap Alma API requests
class AlmaApi
  class RequestFailedError < StandardError; end

  class BibNotFound < StandardError; end

  ALMA_API_BASE_URL = 'https://api-na.hosted.exlibrisgroup.com'
  DEFAULT_HEADERS = { "Authorization": "apikey #{ENV['ALMA_KEY']}" }.freeze

  # @param [String] bib_id in Alma format
  # @option [TrueClass, FalseClass] availability
  # @return [String] bib information as XML
  def self.bib(bib_id, availability: true)
    params = availability ? { expand: 'p_avail', mms_id: bib_id } : { mms_id: bib_id }
    conn = Faraday.new(url: ALMA_API_BASE_URL, params: params,
                       headers: DEFAULT_HEADERS)
    response = conn.get('/almaws/v1/bibs')

    raise RequestFailedError, "Request failed: #{response.body}" unless response.success?

    raise BibNotFound, "Bib not found in Alma for #{bib_id}" if response.body =~ /total_record_count="0"/

    response.body
  end
end
