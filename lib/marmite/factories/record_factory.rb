# frozen_string_literal: true

require_relative '../services/alma_api'
require_relative '../models/alma_bib'

# Create Record objects corresponding to metadata types
class RecordFactory
  # TODO: update case? may want to receive a existing record here and only update the blob field....
  #       or.....??? also, consider the 'freshness' logic which should be considered prior to this
  #       code being executed...right?
  def self.create_marc21_record(bib_id)
    bib_xml = AlmaApi.bib bib_id
    alma_bib = AlmaBib.new bib_xml
    transformed_xml = alma_bib.transform
    Record.create! blob: Record.compress(transformed_xml),
                   format: 'marc21'
  rescue AlmaApi::RequestFailedError => e
    e.message
  end

  def self.create_iiif_manifest_record; end
end
