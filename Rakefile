require 'sinatra/activerecord/rake'
require './application'
require'./lib/marmite'

namespace :marmite do
  desc "Process structural metadata spreadsheets in <xlsx_dir> for the specified <format>"
  task :index_structural, :xlsx_dir, :format do |t, args|

    xlsx_dir = args[:xlsx_dir]
    raise "XLSX directory must be specified" if xlsx_dir.nil?

    format = args[:format]&.to_sym
    raise "format must be specified" if format.nil?

    parse_errors = IndexMetadata.index_structural(xlsx_dir, format)

    unless parse_errors.empty?
      STDERR.puts parse_errors.join("\n")
      exit(1)
    end
  end

  desc "Process descriptive and structural metadata spreadsheets in <xlsx_dir> for the specified <format>"
  task :index_combined, :xlsx_dir, :format do |t, args|

    xlsx_dir = args[:xlsx_dir]
    raise "XLSX directory must be specified" if xlsx_dir.nil?

    format = args[:format]&.to_sym
    raise "format must be specified" if format.nil?

    parse_errors = IndexMetadata.index_combined(xlsx_dir, format)

    unless parse_errors.empty?
      STDERR.puts parse_errors.join("\n")
      exit(1)
    end
  end
end
