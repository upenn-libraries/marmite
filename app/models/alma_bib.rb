# frozen_string_literal: true

# represent an Alma MRC XML record, and output a transformed version
# for saving as a Record blob
class AlmaBib
  class MarcTransformationError < StandardError; end

  # @param [String] bib_xml
  def initialize(bib_xml)
    @xml = bib_xml
    @doc = Nokogiri::XML(bib_xml) do |config|
      config.options = Nokogiri::XML::ParseOptions::NOBLANKS
    end
    @doc.remove_namespaces!
    @record = @doc.xpath '//bibs/bib/record'
  rescue StandardError => e
    raise MarcTransformationError, "MARC transformation error: #{e.message}"
  end

  # crazy XML parsing and restructuring
  # TODO: refactor so that it's more clear what transformations are
  #       being applied to this XML (and why?)
  # @return [String] transformed XML
  def transform
    holdings = extract_holdings
    unsanitized_values = handle_unsanitized_values

    # add 999z to XML reader>record
    if unsanitized_values.any?
      Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
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

    # e.g., remove Alma availability nodes
    @record.search('//record/datafield[@tag="INT"]').remove
    @record.search('//record/datafield[@tag="INST"]').remove
    @record.search('//record/datafield[@tag="AVA"]').remove

    collection_names = extract_collection_names

    # add back collection names to 773.....
    if collection_names.any?
      collection_names.each do |cn|
        Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
          xml.datafield('ind1' => '0', 'ind2' => '0', 'tag' => '773') {
            xml.subfield(cn, 'code' => 't')
          }
        end
      end
    end

    # ??????????????????????????????
    leader = @record.xpath('//record/leader')
    control = @record.xpath('//record/controlfield')
    all_datafields_unsorted = @record.xpath('//datafield')

    all_datafields_sorted = all_datafields_unsorted.sort do |a, b|
      compare_nodes a, b
    end

    build_new_marcxml(leader, control, holdings, all_datafields_sorted)
  rescue StandardError => e
    raise MarcTransformationError, "MARC transformation error: #{e.message}"
  end

  private

  # Used when sorting data field nodes, first compares by tag value, then by node content, ensuring reliable
  # sorting of nodes
  def compare_nodes(node_a, node_b)
    comp = node_a.attribute('tag').value <=> node_b.attribute('tag').value
    comp.zero? ? node_a.content <=> node_b.content : comp
  end

  def build_new_marcxml(leader, control, holdings, all_datafields)
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml['marc'].records('xmlns:marc' => 'http://www.loc.gov/MARC21/slim',
                          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                          'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') {
        xml.record {
          xml << leader.to_xml
          xml << control.to_xml
          all_datafields.each do |datafield|
            xml << datafield.to_xml
          end
          xml.holdings {
            holdings.each do |holding|
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

  # @return [Array]
  def extract_holdings
    holdings = []
    # build holdings hash by iterating through 'special' AVA Alma MARC fields
    for i in 0..(@record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children.length - 1)
      holding_hash = {}
      holding_hash[:holding_id] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].nil?
      holding_hash[:call_number] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].nil?
      holding_hash[:library] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].nil?
      holding_hash[:location] = @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].text unless @record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].nil?
      holdings << holding_hash
    end
    holdings
  end

  # @return [Array]
  def extract_collection_names
    collection_names = []
    @record.xpath('//record/datafield[@tag="710"]').each do |xml_snippet|
      if xml_snippet.children.search('subfield[@code="5"]').any?
        xml_snippet.children.search('subfield[@code="a"]').children.each do |c_name|
          collection_names << c_name.text
        end
      end
    end
    collection_names
  end

  # @return [Array]
  def handle_unsanitized_values
    unsanitized_values = []
    for i in 0..(@record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children.length-1)
      if @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('PRO ')
        unsanitized_values << @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
        provenance = @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^PRO /, '')
        Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
          xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '561') {
            xml.subfield(provenance, 'code' => 'a')
          }
        end
      end
      if @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('CHR ')
        unsanitized_values << @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
        date = @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^CHR /, '')
        Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
          xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '651') {
            xml.subfield(date, 'code' => 'y')
          }
        end
      end
    end
    unsanitized_values
  end
end
