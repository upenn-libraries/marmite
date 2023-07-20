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

  # Transforming MARCXML provided by Alma. Removing/fixing custom Penn metadata practices that lead to undesirable
  # results when metadata is used by external systems.
  #
  # @return [String] transformed XML
  def transform
    remove_custom_chronology_value
    move_custom_provenance_value
    move_collection_names
    copy_holdings

    # Removing some Alma-specific nodes we don't want to expose.
    @record.search('//record/datafield[@tag="INT"]').remove
    @record.search('//record/datafield[@tag="INST"]').remove

    new_marcxml
  rescue StandardError => e
    raise MarcTransformationError, "MARC transformation error: #{e.message}"
  end

  private

  def new_marcxml
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |xml|
      xml['marc'].records('xmlns:marc' => 'http://www.loc.gov/MARC21/slim',
                          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                          'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') do
        xml.record do
          xml << @record.xpath('//record/leader').to_xml
          xml << @record.xpath('//record/controlfield').to_xml
          xml << @record.xpath('//record/datafield').to_xml
          xml << @record.xpath('//record/holdings').to_xml
        end
      end
    }.to_xml
  end

  # Repackaging holding information. This is legacy code, in the future we would want to pull directly from
  # the AVA datafield. Documentation for the AVA field is located here:
  # https://developers.exlibrisgroup.com/alma/apis/docs/bibs/R0VUIC9hbG1hd3MvdjEvYmlicw==/
  def copy_holdings
    Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
      xml.holdings do
        @record.xpath('//record/datafield[@tag="AVA"]').each do |holding|
          next if holding.at_xpath('subfield[@code="8"]').blank?

          xml.holding do
            xml.holding_id holding.at_xpath('subfield[@code="8"]')&.text
            xml.call_number holding.at_xpath('subfield[@code="d"]')&.text
            xml.library holding.at_xpath('subfield[@code="b"]')&.text
            xml.location holding.at_xpath('subfield[@code="j"]')&.text
          end
        end
      end
    end
  end

  # Moving Penn collection names from 710$a to 773$t
  def move_collection_names
    @record.xpath('//record/datafield[@tag="710"]/subfield[@code="5"]').each do |subfield|
      collection = subfield.parent.at_xpath('subfield[@code="a"]').text

      Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
        xml.datafield('ind1' => '0', 'ind2' => '0', 'tag' => '773') do
          xml.subfield(collection, 'code' => 't')
        end
      end

      subfield.parent.remove
    end
  end

  # Chronology values stored in the 650 field have to be removed because otherwise external
  # systems treat them as subjects.
  def remove_custom_chronology_value
    @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').each do |subfield|
      subfield.parent.remove if subfield.text.start_with?('CHR ')
    end
  end

  # Provenance values stored on the 650 have to be moved to a more appropriate place.
  def move_custom_provenance_value
    @record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').each do |subfield|
      next unless subfield.text.start_with?('PRO ')

      # Move value to 561$a
      provenance = subfield.text.gsub(/^PRO /, '')
      Nokogiri::XML::Builder.with(@doc.at('record')) do |xml|
        xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '561') do
          xml.subfield(provenance, 'code' => 'a')
        end
      end

      # Remove field
      subfield.parent.remove
    end
  end
end
