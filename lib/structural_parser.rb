require 'pry-byebug'
require 'rubyXL'

class StructuralParser

  def self.value(cell)
    return cell.nil? || cell.value.nil? ? '' : cell.value
  end

  def self.parseXLSX(xlsx_filename)
    xlsx = RubyXL::Parser.parse(xlsx_filename)
    errors = []

    worksheet = xlsx[0]
    headers = worksheet.sheet_data.rows.shift.cells.map do |cell|
      value(cell)
    end

    ark_index = headers.index('ARK ID')
    seq_index = headers.index('PAGE SEQUENCE')
    vispage_index = headers.index('VISIBLE PAGE')
    toc_index = headers.index('TOC ENTRY')
    filename_index = headers.index('FILENAME')

    # Reference: https://stackoverflow.com/a/28916684
    contents = Hash.new {|h,k| h[k] = []}

    worksheet.sheet_data.rows.each_with_index do |row, i|
      next if row.nil? # accounts for empty rows
      values = row.cells.map do |cell|
        value(cell)
      end

      ark_id = values[ark_index] || ''
      seq = values[seq_index].presence || 0 # Note: rows missing sequence # will be sorted to the top
      vispage = values[vispage_index] || ''
      toc = values[toc_index] || ''
      filename = values[filename_index] || ''
      filename = File.basename(filename, File.extname(filename))

      # i+2 used for line number to account for removal of header row and zero-based indexing
      errors << "#{xlsx_filename}(#{i+2}): ARK ID missing" if ark_id.empty?
      errors << "#{xlsx_filename}(#{i+2}): FILENAME missing" if filename.empty?

      contents[ark_id] << {:seq => seq, :vispage => vispage, :toc => toc, :filename => filename}
    end

    raise errors.join("\n") unless errors.empty?
    contents.each do |k,v|
      v.sort! { |a,b| a[:seq] <=> b[:seq] }
    end

    return contents
  end

  def self.generateXML(ark_id, rows)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.record {
        xml.ark_id(ark_id)
        xml.pages {
          rows.each_with_index do |row, i|
            xml.page(:number => i+1,
                     :seq => row[:seq],
                     :side => row[:seq].to_i.odd? ? "recto" : "verso",
                     :visiblepage => row[:vispage],
                     :image => row[:filename]) {

              xml.tocentry(row[:toc]) unless row[:toc].empty?
            }
          end
        }
      }
    end
    return builder.to_xml
  end
end
