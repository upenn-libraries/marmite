# frozen_string_literal: true

# Wrap Marmite's Alma API requests
class AlmaApi
  class RequestFailedError < StandardError; end

  DEFAULT_HEADERS = {
    apikey: ENV['API_KEY']
  }.freeze

  # @param [String] bib_id in Alma format
  # @option [TrueClass, FalseClass] availability
  # @return [String] bib information as XML
  def self.bib(bib_id, availability: true)
    params = availability ? { expand: 'p_avail' } : {}
    request =
      Typhoeus::Request.new bib_url(bib_id),
                            method: :get,
                            params: params,
                            headers: DEFAULT_HEADERS
    response = request.run
    raise RequestFailedError, "Request failed: #{response.body}" unless response.success?

    response.body
  end

  # @param [String] bib_id aka alma mms_id
  def self.bib_url(bib_id)
    "https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/#{bib_id}"
  end
end
