#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/activerecord'
require 'open-uri'
require 'nokogiri'

require 'sprockets'
require 'sprockets-helpers'

require 'pry' if development?

class Record < ActiveRecord::Base
end

def create_record(bib_id, blob, format)
  record = Record.find_or_initialize_by(:bib_id => bib_id, :format => format)
  record.format = format
  record.blob = blob
  record.save!
end

def with_holdings_call_number(holdings, record, alma_key)
  holdings_url = "#{holdings.first.attributes["link"].value}/?apikey=#{alma_key}"
  holdings_xml = Nokogiri::XML.parse(open(holdings_url))
  call_number = holdings_xml.xpath('//holdings/holding/call_number').first.children.first.text
  replace_cn = record.xpath('//record/datafield[@tag=099]/subfield')
  return record if replace_cn.empty?
  replace_cn.children.first.content = call_number
  return record
end

def with_structural_metadata(bib_id, legacy_prefix)
  structural_endpoint = "http://dla.library.upenn.edu/dla/#{legacy_prefix.downcase}/pageturn.xml?id=#{legacy_prefix.upcase}_#{legacy_bib_id(bib_id)}"
  data = Nokogiri::XML.parse(open(structural_endpoint))
  pages = data.xpath('//xml/page')
  record = Nokogiri::XML::Builder.new do |xml|
    xml.record {
      xml.bib_id bib_id
      xml.pages {
        xml << pages.to_xml
      }
    }
  end
  return record
end

def legacy_bib_id(bib_id)
  return bib_id[2..8]
end

class Application < Sinatra::Base
  set :assets, Sprockets::Environment.new(root)

  configure do
    assets.append_path File.join(root, 'assets', 'stylesheets')
  end

  helpers do
    def link_to(url_fragment, path)
      port = request.port.nil? ? '' : ":#{request.port}"
      url = "#{request.scheme}://#{request.host}#{port}/#{url_fragment}"
      return "<a href=\"#{url}\">#{path}</a>"
    end

    def correct_partial(list, list_type)
      @list_type = list_type
      @list = list
      return :_empty if list.empty?
      return :_list
    end
  end

  LEGACY_PREFIXES = %w[MEDREN PRINT]
  AVAILABLE_FORMATS = %w[marc21 structural]

  bibs_url = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs'
  alma_key = ENV['ALMA_KEY']

  get '/records/:bib_id/create/?' do |bib_id|
    return 'No key available' if alma_key.nil?

    if params[:structural_metadata]
      return 'Specify legacy_prefix' if params[:legacy_prefix].nil?
      structural_record = with_structural_metadata(bib_id, params[:legacy_prefix])
      create_record(bib_id, structural_record.to_xml, 'structural')
      redirect "/records/#{bib_id}/show?format=structural"
    end

    blob = ''
    path = "#{bibs_url}/?mms_id=#{bib_id}&apikey=#{alma_key}"

    begin
      open(path) { |io| blob = io.read }
    rescue => exception
      return "#{exception.message} returned by source for #{bib_id}"
    end

    return "No record data available at source for #{bib_id}" if blob.empty?

    reader = Nokogiri::XML.parse(blob)
    record = reader.xpath('//bibs/bib/record')
    record = with_holdings_call_number(reader.xpath('//bibs/bib/holdings'), record, alma_key)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml['marc'].records('xmlns:marc' => 'http://www.loc.gov/MARC21/slim', 'xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') {
        xml << record.to_xml
      }
    end
    create_record(bib_id, builder.to_xml, 'marc21')
    redirect "/records/#{bib_id}/show?format=marc21"

  end

  get '/records/:bib_id/show/?' do |bib_id|
    return "Specify one of the following formats: #{AVAILABLE_FORMATS}" if params[:format].nil?
    format = params[:format]
    blob = Record.where(:bib_id => bib_id, :format => format).pluck(:blob)
    return "XML of format \"#{format}\" not found for bib_id \"#{bib_id}\"" if blob.empty?
    content_type('text/xml')
    return blob
  end

  %w[/? /records/?].each do |path|
    get path do
      @marc21_records = Record.where(:format => 'marc21')
      @structural_records = Record.where(:format => 'structural')
      erb :index
    end
  end

  %w[/formats/? /available_formats/? /records/formats/?].each do |path|
    get path do
      @available_formats = AVAILABLE_FORMATS
      erb :available_formats
    end
  end

  %w[/harvesting/? /records/harvesting/?].each do |path|
    get path do
      erb :harvesting
    end
  end

end
