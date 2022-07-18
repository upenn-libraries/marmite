require 'open-uri'

# Class to query the structural metadata lookup service (hosted on mgibney's dev machine) and then transform the xml
# into the expected xml format. This class should be short-lived because we will need to stop using this lookup service
# soon. After we stop using the lookup service, Marmite will continue to serve up data that was cached from this endpoint.
class StructuralMetadataService
  def initialize(bib_id)
    @bib_id = bib_id
  end

  def fetch_and_transform
    doc = get_structural_for(@bib_id)
    doc = get_structural_for(@bib_id[2..-8]) if doc.nil? && @bib_id.length > 7

    return if doc.nil?
    transform(doc)
  end

  # Returns Nokogiri document if structural metadata present
  def get_structural_for(bib_id)
    doc = Nokogiri::XML.parse open(structural_url(bib_id))
    pages = doc.xpath('//pagelevel/page')

    (pages.empty?) ? nil : doc
  end

  def structural_url(bib_id)
    "http://mgibney-dev.library.upenn.int:8084/lookup/#{bib_id}.xml"
  end

  def transform(doc)
    pages = doc.xpath('//pagelevel/page')
    structural = Nokogiri::XML::Builder.new do |xml|
      xml.record {
        xml.bib_id @bib_id
        xml.pages {
          pages.each do |page|
            pid = page.at_xpath('p_id').children.first.to_s
            sequence = page.at_xpath('sequence').children.first.to_s
            filename = page.at_xpath('filename').children.first.to_s
            visible_page = page.at_xpath('visiblepage').children.first.to_s

            if page.at_xpath('tocs')
              tocentries = page.at_xpath('tocs').children.map do |c|
                child_text = c.at_xpath('title').children.first.to_s
                prefix = %w[TOC: ILL:].include?(child_text[0..3]) ? child_text.slice!(0..4) : 'toc'
                [prefix[0..2].downcase, child_text]
              end
            end

            side = sequence.to_i.odd? ? 'recto' : 'verso'

            xml.page(
              'number' => sequence, 'id' => "#{@bib_id}_#{pid}", 'seq' => sequence, 'side' => side,
              'image.id' => filename, 'image' => filename, 'visiblepage' => visible_page
            ) {
              (tocentries || []).each do |tocentry|
                xml.send('tocentry', { name: tocentry[0] }, tocentry[1])
              end
            }
          end
        }
      }
    end

    blob = structural.to_xml
  end
end