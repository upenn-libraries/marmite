class IndexMetadata

  def self.index_structural(xlsx_dir, format)
    parse_errors = []

    Dir.glob("#{xlsx_dir}/*.xlsx").each do |filename|
      begin
        contents = StructuralParser.parseXLSX(filename)
      rescue => parse_error
        parse_errors << parse_error.message
        next
      end

      contents.each do |key, rows|
        ark_id, bib_id = key
        xml = StructuralParser.generateXML(ark_id, bib_id, rows)
        record = Record.find_or_initialize_by(:bib_id => ark_id.tr(":/", "+="), :format => format)
        record.format = format
        record.blob = Base64.encode64(Zlib::Deflate.new(nil, -Zlib::MAX_WBITS).deflate(xml, Zlib::FINISH))
        record.touch unless record.new_record?
        record.save!
      end
    end

    return parse_errors
  end

  def self.index_combined(xlsx_dir, format)
    parse_errors = []

    Dir.glob("#{xlsx_dir}/*.xlsx").each do |filename|
      begin
        contents = CombinedParser.parseXLSX(filename)
      rescue => parse_error
        parse_errors << parse_error.message
        next
      end

      contents.each do |ark_id, rows|
        xml = CombinedParser.generateXML(rows)
        record = Record.find_or_initialize_by(:bib_id => ark_id.tr(":/", "+="), :format => format)
        record.format = format
        record.blob = Base64.encode64(Zlib::Deflate.new(nil, -Zlib::MAX_WBITS).deflate(xml, Zlib::FINISH))
        record.touch unless record.new_record?
        record.save!
      end
    end

    return parse_errors
  end
end
