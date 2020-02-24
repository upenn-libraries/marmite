#!/usr/bin/env ruby

require './lib/marmite'

require 'sinatra'
require 'sinatra/activerecord'
require 'active_support/core_ext/string/output_safety'
require 'open-uri'
require 'nokogiri'
require 'json'
require 'iiif/presentation'
require 'htmlentities'

require 'sprockets'
require 'sprockets-helpers'

require 'pry' if development?

use Rack::Logger

use Rack::Deflater, :if => lambda {
    |*, body| body.map(&:bytesize).reduce(0, :+) > 512
}

class Record < ActiveRecord::Base

  @error_message = ''

  def self.error_message
    return @error_message
  end

  def self.error_message=(value)
    @error_message = value
  end

end

def xpath_empty?(array)
  return array.nil?
end

def inflate(string)
  zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
  buf = zstream.inflate(Base64::decode64(string))
  zstream.finish
  zstream.close
  buf
end

def retrieve_pages(bib_id)
  structural_endpoint = "http://mgibney-dev.library.upenn.int:8084/lookup/#{bib_id}.xml"
  data = Nokogiri::XML.parse(open(structural_endpoint))
  pages = data.xpath('//pagelevel/page')
  if pages.empty? && bib_id.length > 7
    bib_id = bib_id[2..-8]
    pages = retrieve_pages(bib_id)
  end
  return pages
end

def create_record(bib_id, format, options = {})
  skip_update = false

  case format
    when 'marc21'
      bibs_url = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs'
      alma_key = ENV['ALMA_KEY']
      return logger.warn('No key available') if alma_key.nil?
      source_blob = ''
      bib_id = validate_bib_id(bib_id)
      path = "#{bibs_url}/?mms_id=#{bib_id}&expand=p_avail&apikey=#{alma_key}"
      begin
        open(path) { |io| source_blob = io.read }
      rescue => exception
        Record.error_message = "#{exception.message} returned by source for #{bib_id}"
        return
      end

      if source_blob.empty?
        Record.error_message = "No record data available at source for #{bib_id}"
        return
      end

      reader = Nokogiri::XML(source_blob) do |config|
        config.options = Nokogiri::XML::ParseOptions::NOBLANKS
      end

      record = reader.xpath('//bibs/bib/record')

      holdings = {}
      unsanitized_values = []

      for i in 0..(record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children.length-1)
        holdings_hash = {}
        holdings_hash[:holding_id] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].nil?
        holdings_hash[:call_number] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].nil?
        holdings_hash[:library] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].nil?
        holdings_hash[:location] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].nil?
        holdings[i] = holdings_hash
      end

      for i in 0..(record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children.length-1)
        if record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('PRO ')
          unsanitized_values << record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
          provenance = record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^PRO /,'')
          Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
            xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '561') {
              xml.subfield(provenance, 'code' => 'a')
            }
          end
        end
        if record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('CHR ')
          unsanitized_values << record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
          date = record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^CHR /,'')
          Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
            xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '651') {
              xml.subfield(date, 'code' => 'y')
            }
          end
        end
      end

      unless unsanitized_values.empty?
        Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
          xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '999') {
            unsanitized_values.each do |value|
              xml.subfield(value, 'code' => 'z')
            end
          }
        end
      end

      record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "CHR ")]').remove
      record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "PRO ")]').remove
      record.search('//record/datafield[@tag="650"][not(node())]').remove
      record.search('//record/datafield[@tag="INT"]').remove
      record.search('//record/datafield[@tag="INST"]').remove
      record.search('//record/datafield[@tag="AVA"]').remove

      collection_names = []

      record.xpath('//record/datafield[@tag="710"]').each do |xml_snippet|
        if xml_snippet.children.search('subfield[@code="5"]').any?
          xml_snippet.children.search('subfield[@code="a"]').children.each do |c_name|
            collection_names << c_name.text
          end
        end
      end

      if collection_names.any?
        collection_names.each do |cn|
          Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
            xml.datafield('ind1' => '0', 'ind2' => '0', 'tag' => '773') {
              xml.subfield(cn, 'code' => 't')
            }
          end
        end
      end

      leader  = record.xpath('//record/leader')
      control  = record.xpath('//record/controlfield')
      unsorted  = record.xpath('//datafield')

      sorted = unsorted.sort_by{ |n| n.attribute('tag').value }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml['marc'].records('xmlns:marc' => 'http://www.loc.gov/MARC21/slim', 'xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') {
          xml.record {
            xml << leader.to_xml
            xml << control.to_xml
            sorted.each do |datafield|
              xml << datafield.to_xml
            end
            xml.holdings {
              holdings.each do |holding_key, holding|
                xml.holding {
                  xml.holding_id holding[:holding_id] unless holding[:holding_id].nil?
                  xml.call_number holding[:call_number] unless holding[:call_number].nil?
                  xml.library holding[:library] unless holding[:library].nil?
                  xml.location holding[:location] unless holding[:location].nil?
                }
              end
            }

          }
        }

      end
      blob = builder.to_xml
    when 'structural'
      pages = retrieve_pages(bib_id)
      structural = Nokogiri::XML::Builder.new do |xml|
        xml.record {
          xml.bib_id bib_id
          xml.pages {
            process_pages(pages, xml, bib_id, options[:image_id_prefix])
          }
        }
      end
      blob = structural.to_xml
    when 'dla'
      create_record(validate_bib_id(bib_id), 'marc21') unless still_fresh?(validate_bib_id(bib_id), 'marc21')
      marc21 = inflate(Record.where(:bib_id => validate_bib_id(bib_id), :format => 'marc21').pluck(:blob).first)
      descriptive = Nokogiri::XML(marc21).search('//marc:records/marc:record')
      structural_endpoint = "http://mgibney-dev.library.upenn.int:8084/lookup/#{bib_id}.xml"
      data = Nokogiri::XML.parse(open(structural_endpoint))
      pages = data.xpath('//pagelevel')

      dla = Nokogiri::XML::Builder.new do |xml|
        xml.record('xmlns:marc' => 'http://www.loc.gov/MARC21/slim', 'xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') {
          xml.xml('name' => 'marcrecord') {
            xml << descriptive.to_xml
          }

          xml.xml('name' => 'pages') {
            xml << pages.to_xml
          }

        }
      end
      blob = dla.to_xml
    when 'openn'
      create_record(validate_bib_id(bib_id), 'marc21') unless still_fresh?(validate_bib_id(bib_id), 'marc21')
      marc21 = inflate(Record.where(:bib_id => validate_bib_id(bib_id), :format => 'marc21').pluck(:blob).first)
      descriptive = Nokogiri::XML(marc21).search('//marc:records/marc:record')
      pages = retrieve_pages(bib_id)
      openn = Nokogiri::XML::Builder.new do |xml|
        xml.page {
          xml.result('xmlns:marc' => 'http://www.loc.gov/MARC21/slim', 'xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') {
            xml.xml('name' => 'marcrecord') {
              xml << descriptive.to_xml
            }
            xml.xml('name' => 'pages') {
              process_pages(pages, xml, bib_id, options[:image_id_prefix])
            }
          }

        }
      end
      blob = openn.to_xml
  when 'iiif_presentation'
      image_ids_endpoint = "#{ENV['IMAGE_ID_ENDPOINT_PREFIX']}/#{bib_id}/#{ENV['IMAGE_ID_ENDPOINT_SUFFIX']}"

      logger.info("ATTEMPTING TO PARSE #{image_ids_endpoint}")

      response = JSON.parse(open(image_ids_endpoint).read)

      image_ids = response['image_ids']
      title = response['title']
      reading_direction = response['reading_direction']

      # Title is already HTML-escaped and will be escaped again when
      # transformed to JSON. This prevents double escaping. We could
      # disable HTML escaping entirely, but this is the only field
      # that requires special handling.
      #
      # To disable escaping entirely, un-comment the next line:
      # ActiveSupport::JSON::Encoding.escape_html_entities_in_json = false

      seed = { 'label' => HTMLEntities.new.decode(title) }

      manifest = IIIF::Presentation::Manifest.new(seed)

      manifest["@id"] = "#{ENV['IIIF_SERVER']}/iiif/2/#{bib_id}/manifest"
      manifest["license"] = options[:license]
      manifest["attribution"] = "University of Pennsylvania Libraries"
      manifest["viewingHint"] = reading_direction == "right-to-left" ? "paged" : "individuals"
      manifest["viewingDirection"] = reading_direction

      sequence = IIIF::Presentation::Sequence.new(
        '@id' => "#{ENV['IIIF_SERVER']}/#{bib_id}/sequence/normal",
        'label' => 'Current order'
      )

      structures = []
      
      if image_ids.is_a? Array

        image_ids.each_with_index do |iiif, i|

          iiif_server = "#{ENV['IIIF_SERVER']}/iiif/2/"

          # Account for legacy image ID paths

          iiif = URI(iiif).path.gsub('/iiif/2/','')
          iiif_string = iiif.end_with?("/info.json") ? iiif : iiif + "/info.json"

          p = Net::HTTP.get(URI.parse(iiif_server + iiif_string))

          logger.info("ARRAY -- ITERATING THROUGH #{iiif_server + iiif_string}")


          canvas_json = JSON.parse(p)

          canvas = IIIF::Presentation::Canvas.new()
          canvas["height"] = canvas_json["height"]
          canvas["width"] = canvas_json["width"]
          canvas["@id"] = "#{ENV['IIIF_SERVER']}/#{bib_id}/canvas/p#{i+1}"
          canvas["label"] = "p. #{i+1}"

          annotation = IIIF::Presentation::Annotation.new
          base_uri = "#{iiif_server}#{iiif}"
          params = {service_id: base_uri}
          annotation.resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(params)
          annotation["on"] = (canvas["@id"])

          canvas.images << annotation

          sequence.canvases << canvas

        end

      elsif image_ids.is_a? Hash

        image_ids.each_with_index do |(iiif, i), index|

          next unless iiif.ends_with?('.tif.jpeg')

          iiif_server = "#{ENV['IIIF_SERVER']}/iiif/2/"

          iiif_string = iiif.start_with?(iiif_server) ? "#{iiif}/info.json" : iiif_server + "#{iiif}/info.json"

          p = Net::HTTP.get(URI.parse(iiif_string))

          logger.info("HASH -- ITERATING THROUGH #{iiif_string}")

          canvas_json = JSON.parse(p)

          canvas = IIIF::Presentation::Canvas.new()
          canvas["height"] = canvas_json["height"]
          canvas["width"] = canvas_json["width"]

          canvas["@id"] = "#{ENV['IIIF_SERVER']}/#{bib_id}/canvas/p#{index+1}"
          canvas["label"] = i["description"].present? ? i["description"] : "p. #{index+1}"

          annotation = IIIF::Presentation::Annotation.new
          base_uri = "#{iiif_server}#{iiif}"
          params = {service_id: base_uri}
          annotation.resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(params)
          annotation["on"] = (canvas["@id"])

          canvas.images << annotation

          sequence.canvases << canvas

          struct_desc = i['description'].length > 2 ? "#{i["description"]};" : nil
          struct_tocentry = i['tocentry_data'].present? ? "#{i["tocentry_data"]['ill']};" : nil
          structural_label = "#{struct_desc}#{struct_tocentry}"

          structures << { "@id" => "#{ENV['IMAGE_ID_ENDPOINT_PREFIX']}/#{bib_id}/p#{index+1}",
                          "@type" => "sc:Range",
                          "label" => structural_label,
                          "canvases" => [canvas["@id"]]

          } if structural_label.present?

        end

      else

      end

      manifest.sequences << sequence

      manifest.structures = structures

      blob = manifest.to_json
    when 'structural_ark'
      skip_update = true
      targetpath = Pathname.new(ENV['TASK_BASE_PATH'] + "/" + bib_id + ".xlsx")
      parse_errors = IndexMetadata.index_structural(targetpath.to_path, format)

      if !parse_errors.empty?
        status 500 unless parse_errors.empty?
        content_type('application/json')
        return JSON(parse_errors)
      end
    when 'combined_ark'
      skip_update = true
      targetpath = Pathname.new(ENV['TASK_BASE_PATH'] + "/" + bib_id + ".xlsx")
      parse_errors = IndexMetadata.index_combined(targetpath.to_path, format)

      if !parse_errors.empty?
        status 500 unless parse_errors.empty?
        content_type('application/json')
        return JSON(parse_errors)
      end
  else
    return
  end

  unless skip_update
    record = Record.find_or_initialize_by(:bib_id => bib_id, :format => format)
    record.format = format
    record.blob = Base64.encode64(Zlib::Deflate.new(nil, -Zlib::MAX_WBITS).deflate(blob, Zlib::FINISH))
    record.touch unless record.new_record?
    record.save!
  end
end

def process_pages(pages, xml, bib_id, image_id_prefix = '')

  pages.each do |page|
    pid = page.at_xpath('p_id').children.first.to_s
    sequence = page.at_xpath('sequence').children.first.to_s
    filename = page.at_xpath('filename').children.first.to_s
    visible_page = page.at_xpath('visiblepage').children.first.to_s
    tocentries = []
    if !(page.at_xpath('tocs').nil?)
      page.at_xpath('tocs').children.each do |c|
        child_text = c.at_xpath('title').children.first.to_s
        prefix = %w[TOC: ILL:].include?(child_text[0..3]) ? child_text.slice!(0..4) : 'toc'
        tocentries << [prefix[0..2].downcase, child_text]
      end
    end

    side = sequence.to_i.odd? ? 'recto' : 'verso'

    filename = "#{image_id_prefix.downcase}#{filename}" unless image_id_prefix.nil?
    xml.send('page',{'number' => sequence,
                     'id' => "#{bib_id}_#{pid}",
                     'seq' => sequence,
                     'side' => side,
                     'image.id' => filename,
                     'image' => filename,
                     'visiblepage' => visible_page}) {
      tocentries.each do |tocentry|
        xml.send('tocentry', {'name' => tocentry[0]}, tocentry[1])
      end
    }
  end
end

###
#
# Deprecated method -- leaving in for potential re-use for visiblepage
#
###
def determine_side(side_value, sequence)
  side_hash = { 'r' => 'recto',
                'v' => 'verso'
  }

  return side_hash[side_value[1]] unless (/\A[[:digit:]][[:alnum:]]*[rv]\Z/ =~ side_value).nil?

  return sequence.to_i.odd? ? 'recto' : 'verso'
end

def dla_structural_metadata(bib_id, sceti_prefix)
  bib_id = validate_bib_id(bib_id)
  structural_endpoint = "http://dla.library.upenn.edu/dla/#{sceti_prefix.downcase}/pageturn.xml?id=#{sceti_prefix.upcase}_#{bib_id}"
  data = Nokogiri::XML.parse(open(structural_endpoint))
  pages = data.xpath('//xml/page')
  record = Nokogiri::XML::Builder.new do |xml|
    xml.record {
      xml.bib_id bib_id
      xml.pages {
        xml << pages.to_xml
      }
    }
  end
  return record.to_xml
end

def validate_bib_id(bib_id)
  return bib_id.length <= 7 ? "99#{bib_id}3503681" : bib_id
end

def legacy_bib_id(bib_id)
  return bib_id[2..(bib_id.length-8)] if bib_id.start_with?('99') and bib_id.end_with?('3503681')
end

def still_fresh?(bib_id, format)
  # Recreate ark formats every time
  return false if ['structural_ark', 'combined_ark'].member?(format)

  record_check = Record.find_or_initialize_by(:bib_id => bib_id, :format => format)
  fresh = record_check.updated_at.nil? ? false : fresh_check(record_check.updated_at)
  if fresh
    logger.info("NOT RECREATING #{bib_id} -- object was updated within past 24 hours")
    return true
  else
    logger.info("CREATING/RECREATING #{bib_id} -- object has not been updated within past 24 hours")
    return false
  end
end

def fresh_check(updated_at)
  current_time = Time.now.gmtime
  yesterday = current_time - 1.day
  return (yesterday..current_time).cover?(Time.at(updated_at).gmtime)
end

class Application < Sinatra::Base
  set :assets, Sprockets::Environment.new(root)

  configure do
    set :protection, :except => [:json_csrf]
    enable :logging
    use Rack::CommonLogger, STDOUT
    assets.append_path File.join(root, 'assets', 'stylesheets')
    assets.append_path File.join(root, 'assets', 'images')
  end

  helpers do
    def link_to(url_fragment, path)
      port = request.port.nil? ? '' : ":#{request.port}"
      url = "#{request.scheme}://#{request.host}#{port}/#{url_fragment}"
      return "<a href=\"#{url}\">#{path}</a>"
    end

    def correct_partial(list, list_type)
      @list_type = list_type
      @list = list
      return :_empty if list.empty?
      return :_list
    end
  end

  AVAILABLE_FORMATS = %w[marc21 structural structural_ark combined_ark dla openn iiif_presentation]
  FORMAT_OVERRIDES = { 'iiif_presentation' => 'application/json' }
  IMAGE_ID_PREFIXES = %w[medren_ print_]

  get '/records/:bib_id/create/?' do |bib_id|
    Record.error_message = ''

    format = params[:format].nil? ? 'marc21' : params[:format]

    fresh = still_fresh?(bib_id, format)

    redirect "/records/#{bib_id}/show?format=#{format}" if fresh

    case format
      when 'structural'
         create_record(bib_id, 'structural', params)
      when 'marc21'
        create_record(bib_id, 'marc21')
      when 'dla'
        create_record(bib_id, 'dla', params)
      when 'openn'
        create_record(bib_id, 'openn', params)
      when 'iiif_presentation'
        create_record(bib_id, 'iiif_presentation', params)
      when 'structural_ark'
        create_record(bib_id, 'structural_ark', params)
      when 'combined_ark'
        create_record(bib_id, 'combined_ark', params)
      else
        return "Invalid format \"#{format}\" specified"
    end

    Record.error_message = "Invalid specified format #{format}" unless AVAILABLE_FORMATS.include?(format)

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

  %w[/? /records/?].each do |path|
    get path do
      @marc21_records = Record.where(:format => 'marc21')
      @structural_records = Record.where(:format => 'structural')
      @structural_ark_records = Record.where(:format => 'structural_ark')
      @combined_ark_records = Record.where(:format => 'combined_ark')
      @dla_records = Record.where(:format => 'dla')
      @openn_records = Record.where(:format => 'openn')
      @iiif_presentation_records = Record.where(:format => 'iiif_presentation')
      erb :index
    end
  end

  %w[/formats/? /available_formats/? /records/formats/?].each do |path|
    get path do
      @available_formats = AVAILABLE_FORMATS
      erb :available_formats
    end
  end

  %w[/image_id_prefixes/? /records/image_id_prefixes/?].each do |path|
    get path do
      @image_id_prefixes = IMAGE_ID_PREFIXES
      erb :image_id_prefixes
    end
  end

  %w[/harvesting/? /records/harvesting/?].each do |path|
    get path do
      erb :harvesting
    end
  end

end
