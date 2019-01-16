require 'sinatra/activerecord/rake'
require './application'
require './lib/structural_parser'

namespace :marmite do
  desc "Process structural metadata spreadsheets in <xlsx_dir> for the specified <format>"
  task :index_structural, :xlsx_dir, :format do |t, args|

    xlsx_dir = args[:xlsx_dir]
    raise "XLSX directory must be specified" if xlsx_dir.nil?

    format = args[:format]&.to_sym
    raise "format must be specified" if format.nil?

    parse_errors =[]

    Dir.glob("#{xlsx_dir}/*.xlsx").each do |filename|
      begin
        contents = StructuralParser.parseXLSX(filename)
      rescue => parse_error
        parse_errors << parse_error.message
        next
      end

      contents.each do |ark_id, rows|
        xml = StructuralParser.generateXML(ark_id, rows)
        record = Record.find_or_initialize_by(:bib_id => ark_id.tr(":/", "+="), :format => format)
        record.format = format
        record.blob = Base64.encode64(Zlib::Deflate.new(nil, -Zlib::MAX_WBITS).deflate(xml, Zlib::FINISH))
        record.touch unless record.new_record?
        record.save!
      end
    end

    unless parse_errors.empty?
      STDERR.puts parse_errors.join("\n")
      exit(1)
    end
  end
end
