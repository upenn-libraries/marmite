class CombinedParser

  def self.value(cell)
    return cell.nil? || cell.value.nil? ? '' : cell.value
  end

  def self.parseXLSX(xlsx_filename)
    header_map = ["ABSTRACT","CONTRIBUTOR","COVERAGE","CREATOR","DATE","DESCRIPTION","FORMAT","IDENTIFIER","INCLUDES","LANGUAGE","PUBLISHER","RELATION","RIGHTS","SOURCE","SUBJECT","TITLE","INCLUDES COMPONENT","TYPE","FILENAME(S)"]

    header_map.map! { |h| [h, {:tag => "pqc:#{h.downcase.tr(' ', '_')}"}]} .to_h

    xlsx = RubyXL::Parser.parse(xlsx_filename)
    worksheet = xlsx[0]
    xlsx_headers = worksheet.sheet_data.rows.shift.cells.map do |cell|
      value(cell)
    end

    header_map.each { |k,v|
      v[:idx] = xlsx_headers.index(k)
    }

    header_map.reject! { |k,v|
      v[:idx].nil?
    }

    # Reference: https://stackoverflow.com/a/28916684
    contents = Hash.new {|h,k| h[k] = []}

    worksheet.sheet_data.rows.each_with_index do |row, i|
      next if row.nil? # accounts for empty rows
      values = row.cells.map do |cell|
        value(cell)
      end
      values = header_map.map { |k,v|
        [v[:tag], values[v[:idx]] || '']
      }.to_h

      values["pqc:subject"] = values["pqc:subject"].split("|").reject(&:empty?)

      id = values.delete("pqc:identifier")
      contents[id] = values
    end

    return contents
  end

  def self.generateXML(ark_id, values)
    filename = values.delete("pqc:filename(s)")
    filename = File.basename(filename, File.extname(filename)) unless filename.empty?

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.record('xmlns:pqc' => 'http://www.library.upenn.edu/pqc') {
        xml.ark_id(ark_id)
        xml.descriptive {
          values.each do |k,v|
            [v].flatten.each do |mv|
              xml.send(k, mv.to_s) unless mv.to_s.empty?
            end
          end
        }
       xml.pages {
         xml.page(:number => 1, :seq => 1, :side => 'recto', :visiblepage => 1, :image => filename)
       }
      }
    end

    return builder.to_xml
  end
end
