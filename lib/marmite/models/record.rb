require 'sinatra/activerecord'
require_relative '../services/alma_api'
require_relative '../services/blob_handler'
require_relative './alma_bib'

class Record < ActiveRecord::Base

  FORMATS_TO_ALWAYS_RECREATE = %w[structural_ark combined_ark iiif_presentation]

  @error_message = ''

  def self.error_message
    @error_message
  end

  def self.error_message=(value)
    @error_message = value
  end

  # @param [String] uncompressed_blob
  def uncompressed_blob=(uncompressed_blob)
    self.blob = BlobHandler.compress uncompressed_blob
  end

  # @return [String] uncompressed blob
  def uncompressed_blob
    BlobHandler.uncompress self[:blob]
  end

  # @return [TrueClass, FalseClass]
  def update_blob
    self.uncompressed_blob = send("update_#{self[:format]}_blob")
    save
  end

  # A record is fresh if it is:
  # - NOT one of the FORMATS_TO_ALWAYS_RECREATE
  # AND
  # - less than 1 day old
  # @return [TrueClass, FalseClass]
  def fresh?
    return false if FORMATS_TO_ALWAYS_RECREATE.include?(format)

    return false unless updated_at # new record - too fresh!

    current_time = Time.now.gmtime
    yesterday = current_time - 1.day
    (yesterday..current_time).cover?(Time.at(updated_at).gmtime)
  end

  private

  def update_marc21_blob
    bib_xml = AlmaApi.bib bib_id
    alma_bib = AlmaBib.new bib_xml
    alma_bib.transform
  end

  def update_openn_blob; end

  def update_structural_blob; end

  def update_iiif_presentation_blob; end

end
