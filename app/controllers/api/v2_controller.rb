require_relative '../../controllers/base_controller'
require_relative '../../services/alma_api'
require_relative '../../services/blob_handler'
require_relative '../../services/structural_metadata_service'
require_relative '../../models/alma_bib'
require_relative '../../models/iiif_presentation'
require_relative '../../models/record'

class Api
  class V2Controller < BaseController
    # pull XML from Alma, do some processing, and save a Record with the XML
    # as a blob. return the XML.
    get '/api/v2/records/:bib_id/marc21' do |bib_id|
      record = Record.find_or_initialize_by bib_id: long_bib_id(bib_id),
                                            format: Record::MARC_21
      update_blob = update_blob? params[:update], record
      status = if record.persisted? && !update_blob
                 # record exists and shouldn't be updated
                 200
               else
                 begin
                   # record is new or should be updated
                   record.set_blob
                   201
                 rescue AlmaBib::MarcTransformationError => e
                   error = error_response e.message
                   500
                 rescue AlmaApi::BibNotFound => e
                   error = error_response e.message
                   404
                 end
               end

      body = if error
               content_type 'application/json'
               error
             else
               content_type 'text/xml', charset: 'utf-8'
               record.uncompressed_blob
             end
      [status, body]
    end

    get '/api/v2/records/:bib_id/structural' do |bib_id|
      bib_id = long_bib_id(bib_id)

      # Retrieve record from database if present, otherwise query service
      if (record = Record.find_by(bib_id: bib_id, format: Record::STRUCTURAL))
        document = Nokogiri::XML.parse(record.uncompressed_blob)

        if document.xpath('//record/pages/page').empty?
          content_type 'application/json'
          [404, error_response("Record not found.")]
        else
          content_type 'text/xml'
          [200, record.uncompressed_blob]
        end
      else
        metadata = StructuralMetadataService.new(bib_id).fetch_and_transform
        if metadata
          record = Record.new(bib_id: bib_id, format: Record::STRUCTURAL)
          record.uncompressed_blob = metadata
          record.save!
          content_type 'text/xml'
          [201, metadata]
        else
          content_type 'application/json'
          [404, error_response('Record not found.')]
        end
      end
    end

    # Pulls IIIF manifest from database and returns it.
    get '/api/v2/records/:id/iiif_presentation' do |id|
      content_type 'application/json'

      if (record = Record.find_by(bib_id: id, format: Record::IIIF_PRESENTATION))
        [200, record.uncompressed_blob]
      else
        [404, error_response("Record not found.")]
      end
    end

    # Creates IIIF presentation manifest using the body of the post request.
    post '/api/v2/records/:id/iiif_presentation' do |id|
      data = JSON.parse(request.body.read)

      record = Record.find_or_initialize_by(bib_id: id, format: Record::IIIF_PRESENTATION)
      content_type 'application/json'

      begin
        record.set_blob(data)
        [201, record.uncompressed_blob]
      rescue => e
        logger.error(e.message)
        logger.error(e.backtrace.join("\n"))
        [500, error_response('Unexpected error generating IIIF manifest.')]
      end
    end

    # NOTE: doesn't check format
    # @param [String] update_param
    # @return [TrueClass, FalseClass]
    def update_blob?(update_param, record)
      return true if record.new_record?

      case update_param
      when 'always' then true
      when 'never' then false
      when /\d+/
        range = record.updated_at..(record.updated_at + update_param.to_i.hours)
        !range.cover?(Time.now)
      else
        false # don't update if no param is set
      end
    end

    def long_bib_id(bib_id)
      bib_id.length <= 7 ? "99#{bib_id}3503681" : bib_id
    end

    # @param [Array] errors
    # @return [Hash{Symbol->Unknown}]
    def error_response(errors)
      { errors: Array.wrap(errors) }.to_json
    end
  end
end
