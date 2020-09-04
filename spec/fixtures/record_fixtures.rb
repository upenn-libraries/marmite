module RecordFixtures
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