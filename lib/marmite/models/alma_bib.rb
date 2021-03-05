# frozen_string_literal: true

# represent an Alma MRC XML record, and output a transformed version
# for saving as a Record blob
class AlmaBib
  # @param [String] bib_xml
  def initialize(bib_xml)
    @xml = bib_xml
    @xml_reader = Nokogiri::XML(bib_xml) do |config|
      config.options = Nokogiri::XML::ParseOptions::NOBLANKS
    end
    @record = @xml_reader.xpath '//bibs/bib/record'
  end

  # crazy XML parsing and restructuring
  # TODO: refactor so that it's more clear what transformations are
  #       being applied to this XML (and why?)
  # @return [String] transformed XML
  def transform
    # init holdings hash
    holdings = {}
    # init unsanitized values array? what for?
    unsanitized_values = []

    # build holdings hash by iterating through 'special' AVA Alma MARC fields
    for i in 0..(@record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children.length-1)
      holdings_hash = {}
      holdings_hash[:holding_id] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].nil?
      holdings_hash[:call_number] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].nil?
      holdings_hash[:library] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].nil?
      holdings_hash[:location] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].nil?
      holdings[i] = holdings_hash
    end

    # not sure what's going on here, but adding new XML to reader>record from MARC 650 (provenance?)
    for i in 0..(@record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children.length-1)
      if @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('PRO ')
        unsanitized_values << @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
        provenance = @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^PRO /, '')
        Nokogiri::XML::Builder.with(@xml_reader.at('record')) do |xml|
          xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '561') {
            xml.subfield(provenance, 'code' => 'a')
          }
        end
      end
      if @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('CHR ')
        unsanitized_values << @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
        date = @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^CHR /, '')
        Nokogiri::XML::Builder.with(@xml_reader.at('record')) do |xml|
          xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '651') {
            xml.subfield(date, 'code' => 'y')
          }
        end
      end
    end

    # add 999z to XML reader>record
    unless unsanitized_values.empty?
      Nokogiri::XML::Builder.with(@xml_reader.at('record')) do |xml|
        xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '999') {
          unsanitized_values.each do |value|
            xml.subfield(value, 'code' => 'z')
          end
        }
      end
    end

    # remove some nodes from the xml based on xpath expressions
    # would be helpful to wrap these in descriptive methods
    @record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "CHR ")]').remove
    @record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "PRO ")]').remove
    @record.search('//record/datafield[@tag="650"][not(node())]').remove
    @record.search('//record/datafield[@tag="INT"]').remove
    @record.search('//record/datafield[@tag="INST"]').remove
    @record.search('//record/datafield[@tag="AVA"]').remove

    # initialize collection names array
    collection_names = []

    # get collection names from 710
    @record.xpath('//record/datafield[@tag="710"]').each do |xml_snippet|
      if xml_snippet.children.search('subfield[@code="5"]').any?
        xml_snippet.children.search('subfield[@code="a"]').children.each do |c_name|
          collection_names << c_name.text
        end
      end
    end

    # add back collection names to 773.....
    if collection_names.any?
      collection_names.each do |cn|
        Nokogiri::XML::Builder.with(@xml_reader.at('record')) do |xml|
          xml.datafield('ind1' => '0', 'ind2' => '0', 'tag' => '773') {
            xml.subfield(cn, 'code' => 't')
          }
        end
      end
    end

    # ??????????????????????????????
    leader = @record.xpath('//record/leader')
    control = @record.xpath('//record/controlfield')
    unsorted = @record.xpath('//datafield')

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
    builder.to_xml
  end
end
