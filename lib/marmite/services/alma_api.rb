# frozen_string_literal: true

# Wrap Marmite's Alma API requests
class AlmaApi
  class RequestFailedError < StandardError; end

  BIBS_URL = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs'
  DEFAULT_HEADERS = {
    apikey: ENV['API_KEY']
  }.freeze

  # @param [String] bib_id in Alma format
  # @option [TrueClass, FalseClass] availability
  # @return [String] bib information as XML
  def self.bib(bib_id, availability: true)
    params = availability ? { expand: 'p_avail', mms_id: bib_id } : {}
    request =
      Typhoeus::Request.new BIBS_URL,
                            method: :get,
                            params: params,
                            headers: DEFAULT_HEADERS
    response = request.run
    raise RequestFailedError, "Request failed: #{response.body}" unless response.success?

    response.body
  end
end
