require 'sinatra/activerecord'
require_relative '../services/alma_api'
require_relative '../services/blob_handler'
require_relative './alma_bib'

class Record < ActiveRecord::Base

  FORMATS_TO_ALWAYS_RECREATE = %w[iiif_presentation]

  MARC_21 = 'marc21'.freeze
  STRUCTURAL = 'structural'.freeze
  OPENN = 'openn'.freeze
  IIIF_PRESENTATION = 'iiif_presentation'.freeze
  ALL_FORMATS = [MARC_21, STRUCTURAL, OPENN, IIIF_PRESENTATION].freeze

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
  def set_blob(args = {})
    self.uncompressed_blob = send("#{self[:format]}_blob", args)
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

  def marc21_blob(_args)
    bib_xml = AlmaApi.bib bib_id
    alma_bib = AlmaBib.new bib_xml
    alma_bib.transform
  end

  def openn_blob(_args); end

  def structural_blob(_args); end

  def iiif_presentation_blob(data)
    IIIFPresentation.new(data).manifest
  end
end
