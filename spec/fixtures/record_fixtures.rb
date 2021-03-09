# frozen_string_literal: true

require_relative '../support/fixture_helpers'

module RecordFixtures
  include FixtureHelpers

  # @param [String] bib_id
  # @return [Record]
  def marc21_record(bib_id)
    Record.create(
      bib_id: bib_id,
      format: 'marc21',
      blob: BlobHandler.compress(marc21_post_transform(bib_id))
    )
  end

  # @return [Record]
  def structural_record
    Record.create(
      bib_id: 'test-record', format: 'structural', blob: BlobHandler.compress('test-record-blob')
    )
  end

  # @return [Record]
  def iiif_presentation_record
    Record.create(
      bib_id: 'test-record', format: 'iiif_presentation', blob: BlobHandler.compress('test-record-blob')
    )
  end
end
