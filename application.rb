#!/usr/bin/env ruby


require 'sinatra'
require 'sinatra/activerecord'
require 'active_support/core_ext/string/output_safety'
require 'open-uri'
require 'nokogiri'

require 'sprockets'
require 'sprockets-helpers'

require 'pry' if development?

use Rack::Logger

class Record < ActiveRecord::Base

  @error_message = ''

  def self.error_message
    return @error_message
  end

  def self.error_message=(value)
    @error_message = value
  end

end

def create_record(bib_id, format, options = {})
  case format
    when 'marc21'
      bibs_url = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs'
      alma_key = ENV['ALMA_KEY']
      return logger.warn('No key available') if alma_key.nil?
      source_blob = ''
      path = "#{bibs_url}/?mms_id=#{bib_id}&expand=p_avail&apikey=#{alma_key}"

      begin
        open(path) { |io| source_blob = io.read }
      rescue => exception
        Record.error_message = "#{exception.message} returned by source for #{bib_id}"
        return
      end

      if source_blob.empty?
        Record.error_message = "No record data available at source for #{bib_id}"
        return
      end

      reader = Nokogiri::XML(source_blob) do |config|
        config.options = Nokogiri::XML::ParseOptions::NOBLANKS
      end

      record = reader.xpath('//bibs/bib/record')

      holdings = {}
      unsanitized_values = []

      for i in 0..(record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children.length-1)
        holdings[i] = { :holding_id => record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="8"]').children[i].text,
                        :call_number => record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="d"]').children[i].text,
                        :library => record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="b"]').children[i].text,
                        :location => record.xpath('//record/datafield[@tag="AVA"]/subfield[@code="j"]').children[i].text
        }
      end

      for i in 0..(record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children.length-1)
        if record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('PRO ')
          unsanitized_values << record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
          provenance = record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^PRO /,'')
          Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
            xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '561') {
              xml.subfield(provenance, 'code' => 'a')
            }
          end
        end
        if record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.start_with?('CHR ')
          unsanitized_values << record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text
          date = record.xpath('//record/datafield[@tag="650"]/subfield[@code="a"]').children[i].text.gsub(/^CHR /,'')
          Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
            xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '651') {
              xml.subfield(date, 'code' => 'y')
            }
          end
        end
      end

      Nokogiri::XML::Builder.with(reader.at('record')) do |xml|
        xml.datafield('ind1' => ' ', 'ind2' => ' ', 'tag' => '999') {
          unsanitized_values.each do |value|
            xml.subfield(value, 'code' => 'z')
          end
        }
      end

      record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "CHR ")]').remove
      record.search('//record/datafield[@tag="650"]/subfield[@code="a"][starts-with(text(), "PRO ")]').remove
      record.search('//record/datafield[@tag="650"][not(node())]').remove
      record.search('//record/datafield[@tag="INT"]').remove
      record.search('//record/datafield[@tag="INST"]').remove
      record.search('//record/datafield[@tag="AVA"]').remove

      leader  = record.xpath('//record/leader')
      control  = record.xpath('//record/controlfield')
      unsorted  = record.xpath('//datafield')

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
                  xml.holding_id holding[:holding_id]
                  xml.call_number holding[:call_number]
                  xml.library holding[:library]
                  xml.location holding[:location]
                }
              end
            }

          }
        }

      end
      blob = builder.to_xml
    when 'structural'
      if options[:sceti_prefix].nil?
        Record.error_message = "No sceti_prefix specified for #{bib_id}"
        return
      end
      blob = dla_structural_metadata(bib_id, options[:sceti_prefix])
    when 'dla'
      create_record(bib_id, 'marc21')
      marc21 = Record.where(:bib_id => bib_id, :format => 'marc21').pluck(:blob).first
      descriptive = Nokogiri::XML(marc21).search('//marc:records/marc:record')

      structural_endpoint = "http://mgibney-dev.library.upenn.int:8084/lookup/#{legacy_bib_id(bib_id)}.xml"
      data = Nokogiri::XML.parse(open(structural_endpoint))
      pages = data.xpath('//pagelevel')

      dla = Nokogiri::XML::Builder.new do |xml|
        xml.record('xmlns:marc' => 'http://www.loc.gov/MARC21/slim', 'xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd') {
          xml.xml('name' => 'marcrecord') {
            xml << descriptive.to_xml
          }

          xml.xml('name' => 'pages') {
            xml << pages.to_xml
          }

        }
      end
      blob = dla.to_xml
    else
      return
  end
  record = Record.find_or_initialize_by(:bib_id => bib_id, :format => format)
  record.format = format
  record.blob = blob
  record.touch unless record.new_record?
  record.save!
end

def dla_structural_metadata(bib_id, sceti_prefix)
  structural_endpoint = "http://dla.library.upenn.edu/dla/#{sceti_prefix.downcase}/pageturn.xml?id=#{sceti_prefix.upcase}_#{legacy_bib_id(bib_id)}"
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
  return record.to_xml
end

def legacy_bib_id(bib_id)
  return bib_id[2..(bib_id.length-8)] if bib_id.start_with?('99') and bib_id.end_with?('3503681')
end

def fresh_check(bib_id, updated_at)
  if still_fresh?(updated_at)
    logger.info("NOT RECREATING #{bib_id} -- object was updated within past 24 hours")
    return true
  else
    logger.info("CREATING/RECREATING #{bib_id} -- object has not been updated within past 24 hours")
    return false
  end
end

def still_fresh?(updated_at)
  current_time = Time.now.gmtime
  yesterday = current_time - 1.day
  return (yesterday..current_time).cover?(Time.at(updated_at).gmtime)
end

class Application < Sinatra::Base
  set :assets, Sprockets::Environment.new(root)

  configure do
    enable :logging
    use Rack::CommonLogger, STDOUT
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

  SCETI_PREFIXES = %w[MEDREN PRINT]
  AVAILABLE_FORMATS = %w[marc21 structural dla]

  get '/records/:bib_id/create/?' do |bib_id|
    Record.error_message = ''

    format = params[:format].nil? ? 'marc21' : params[:format]

    record_check = Record.find_or_initialize_by(:bib_id => bib_id, :format => format)
    fresh = record_check.updated_at.nil? ? false : fresh_check(bib_id, record_check.updated_at)

    redirect "/records/#{bib_id}/show?format=#{format}" if fresh

    case format
      when 'structural'
         create_record(bib_id, 'structural', params)
      when 'marc21'
        create_record(bib_id, 'marc21')
      when 'dla'
        create_record(bib_id, 'dla', params)
      else
        return
    end

    Record.error_message = "Invalid specified format #{format}" unless AVAILABLE_FORMATS.include?(format)

    unless Record.error_message.empty?
      error = "#{''.html_safe+Record.error_message}"
      logger.warn(error)
      halt(404, error)
    end

    redirect "/records/#{bib_id}/show?format=#{format}"
  end

  get '/records/:bib_id/show/?' do |bib_id|
    return "Specify one of the following formats: #{AVAILABLE_FORMATS}" if params[:format].nil?

    format = params[:format]

    blob = Record.where(:bib_id => bib_id, :format => format).pluck(:blob)
    Record.error_message = "Record #{bib_id} in #{format} format not found" if blob.empty?

    unless Record.error_message.empty?
      error = "#{''.html_safe+Record.error_message}"
      logger.warn(error)
      halt(404, error)
    end

    content_type('text/xml')
    return blob
  end

  %w[/? /records/?].each do |path|
    get path do
      @marc21_records = Record.where(:format => 'marc21')
      @structural_records = Record.where(:format => 'structural')
      @dla_records = Record.where(:format => 'dla')
      erb :index
    end
  end

  %w[/formats/? /available_formats/? /records/formats/?].each do |path|
    get path do
      @available_formats = AVAILABLE_FORMATS
      erb :available_formats
    end
  end

  %w[/sceti_prefixes/? /records/sceti_prefixes/?].each do |path|
    get path do
      @sceti_prefixes = SCETI_PREFIXES
      erb :sceti_prefixes
    end
  end

  %w[/harvesting/? /records/harvesting/?].each do |path|
    get path do
      erb :harvesting
    end
  end

end
