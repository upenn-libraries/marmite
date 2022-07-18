require_relative '../base_controller'
require_relative '../../models/record'
require_relative '../../helpers/v1_helper'

class Api
  class V1Controller < BaseController
    AVAILABLE_FORMATS = %w[marc21 structural openn iiif_presentation]
    FORMAT_OVERRIDES = { 'iiif_presentation' => 'application/json' }

    helpers V1Helper

    get '/records/:bib_id/create/?' do |bib_id|
      format = params[:format] || 'marc21'

      # initialize or retrieve existing record
      record = Record.find_or_initialize_by bib_id: bib_id, format: format

      # TODO: this is not quite right...
      Record.error_message = ''

      # return existing record if the record is still 'fresh'
      # otherwise, proceed with (re)creating
      redirect "/records/#{bib_id}/show?format=#{format}" if record.fresh?

      # ensure we're working with a valid format
      Record.error_message = "Invalid specified format #{format}" unless AVAILABLE_FORMATS.include?(format)

      # populate record details
      create_record(record, params)

      # error message could be set above or by create_record
      unless Record.error_message.empty?
        error = "#{''.html_safe+Record.error_message}"
        logger.warn(error)
        halt(404, error)
      end

      redirect "/records/#{bib_id}/show?format=#{format}"
    end

    get '/records/:bib_id/show/?' do |bib_id|
      return "Specify one of the following formats: #{AVAILABLE_FORMATS}" if params[:format].nil?
      Record.error_message = ''

      format = params[:format]

      # TODO: due to the use of where here, >1 record could be returned - is this a feature or an oversight?
      # I think it should be
      # blob = Record.find_by(bib_id: bib_id, format: format).pluck(:blob)
      blob = Record.where(:bib_id => bib_id, :format => format).pluck(:blob)
      Record.error_message = "Record #{bib_id} in #{format} format not found" if blob.empty?

      unless Record.error_message.empty?
        error = "#{''.html_safe+Record.error_message}"
        logger.warn(error)
        halt(404, error)
      end

      content_type(FORMAT_OVERRIDES[format] || 'text/xml')
      return inflate(blob.first)
    end
  end
end