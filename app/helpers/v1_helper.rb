require 'open-uri'
require 'htmlentities'

module V1Helper
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

  def create_record(original_record, options = {})
    skip_update = false
    bib_id = original_record.bib_id
    validated_bib_id = validate_bib_id(bib_id)
    format = original_record.format
    case format
    when 'marc21'
      bibs_url = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs'
      alma_key = ENV['ALMA_KEY']
      return logger.warn('No key available') if alma_key.nil?
      source_blob = ''
      path = "#{bibs_url}/?mms_id=#{validated_bib_id}&expand=p_avail&apikey=#{alma_key}"
      begin
        open(path) { |io| source_blob = io.read }
      rescue => exception
        Record.error_message = "#{exception.message} returned by source for #{validated_bib_id}"
        return
      end

      if source_blob.empty?
        Record.error_message = "No record data available at source for #{validated_bib_id}"
        return
      end

      reader = Nokogiri::XML(source_blob) do |config|
        config.options = Nokogiri::XML::ParseOptions::NOBLANKS
      end

      # get record node from xml
      record = reader.xpath('//bibs/bib/record')

      # init holdings hash
      holdings = {}
      # init unsanitized values array? what for?
      unsanitized_values = []

      # build holdings hash by iterating through 'special' AVA Alma MARC fields
      for i in 0..(record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children.length-1)
        holdings_hash = {}
        holdings_hash[:holding_id] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].nil?
        holdings_hash[:call_number] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].nil?
        holdings_hash[:library] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].nil?
        holdings_hash[:location] = record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].text unless record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].nil?
        holdings[i] = holdings_hash
      end

      # not sure what's going on here, but adding new XML to reader>record from MARC 650 (provenance?)
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

      # add 999z to XML reader>record
      unless unsanitized_values.empty?
        Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
          xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '999') {
            unsanitized_values.each do |value|
              xml.subfield(value, 'code' => 'z')
            end
          }
        end
      end

      # remove some nodes from the xml based on xpath expressions
      # would be helpful to wrap these in descriptive methods
      record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "CHR ")]').remove
      record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "PRO ")]').remove
      record.search('//record/datafield[@tag="650"][not(node())]').remove
      record.search('//record/datafield[@tag="INT"]').remove
      record.search('//record/datafield[@tag="INST"]').remove
      record.search('//record/datafield[@tag="AVA"]').remove

      # initialize collection names array
      collection_names = []

      # get collection names from 710
      record.xpath('//record/datafield[@tag="710"]').each do |xml_snippet|
        if xml_snippet.children.search('subfield[@code="5"]').any?
          xml_snippet.children.search('subfield[@code="a"]').children.each do |c_name|
            collection_names << c_name.text
          end
        end
      end

      # add back collection names to 773.....
      if collection_names.any?
        collection_names.each do |cn|
          Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
            xml.datafield('ind1' => '0', 'ind2' => '0', 'tag' => '773') {
              xml.subfield(cn, 'code' => 't')
            }
          end
        end
      end

      # ??????????????????????????????
      leader = record.xpath('//record/leader')
      control = record.xpath('//record/controlfield')
      unsorted = record.xpath('//datafield')

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
    when 'openn'
      # corresponding marc record is needed for openn
      marc_record = Record.find_or_initialize_by bib_id: validated_bib_id, format: 'marc21'
      create_record(marc_record) unless marc_record.fresh?
      marc21 = inflate(marc_record.blob)
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

          iiif = URI(iiif).path.gsub('phalt/','')
          iiif = URI(iiif).path.gsub('iiif/2/','')
          iiif_string = iiif.end_with?("/info.json") ? iiif : iiif + "/info.json"

          p = Net::HTTP.get(URI.parse(iiif_server + iiif_string))

          canvas_json = JSON.parse(p)

          canvas = IIIF::Presentation::Canvas.new()
          canvas["height"] = canvas_json["height"]
          canvas["width"] = canvas_json["width"]
          canvas["@id"] = "#{ENV['IIIF_SERVER']}/#{bib_id}/canvas/p#{i+1}"
          canvas["label"] = "p. #{i+1}"

          annotation = IIIF::Presentation::Annotation.new
          base_uri = "#{iiif_server}#{iiif}"
          base_uri.gsub!("/info.json", "") if base_uri.end_with?("/info.json")
          params = {service_id: base_uri}
          annotation.resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(params)
          annotation["on"] = (canvas["@id"])

          canvas.images << annotation
          sequence.canvases << canvas

        end

      elsif image_ids.is_a? Hash

        image_ids.each_with_index do |(iiif, i), index|

          next unless iiif.end_with?('.tif.jpeg')

          iiif_server = "#{ENV['IIIF_SERVER']}/iiif/2/"

          iiif_string = iiif.start_with?(iiif_server) ? "#{iiif}/info.json" : iiif_server + "#{iiif}/info.json"

          p = Net::HTTP.get(URI.parse(iiif_string))

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
    else
      return
    end

    unless skip_update
      original_record.format = format
      original_record.blob = Base64.encode64(Zlib::Deflate.new(nil, -Zlib::MAX_WBITS).deflate(blob, Zlib::FINISH))
      original_record.touch unless original_record.new_record?
      original_record.save!
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

      # FIXME: Might be better to calculate this based on visible page.
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

  def validate_bib_id(bib_id)
    return bib_id.length <= 7 ? "99#{bib_id}3503681" : bib_id
  end

  # TODO: refactor as you find usages of this
  def inflate(string)
    BlobHandler.uncompress string
  end
end