#!/usr/bin/ruby

require 'sinatra'
require 'sinatra/activerecord'
require 'open-uri'
require 'nokogiri'

require 'pry' if development?

class Record < ActiveRecord::Base
end

def create_record(bib_id, blob, format = 'marc21')
  record = Record.find_or_initialize_by(:bib_id => bib_id)
  record.format = format
  record.blob = blob
  record.save!
end

def blob_with_holdings_call_number(blob)
  data = Nokogiri::XML.parse(blob)
  holdings_url = "#{data.xpath('//bibs/bib/holdings').first.attributes["link"].value}/?apikey=#{@@alma_key}"
  holdings_xml = Nokogiri::XML.parse(open(holdings_url))
  call_number = holdings_xml.xpath('//holdings/holding/call_number').first.children.first.text
  replace_cn = data.xpath('//bibs/bib/record/datafield[@tag=099]/subfield')
  replace_cn.children.first.content = call_number
  return data.to_xml
end

helpers do
  def link_to(url_fragment, path)
    port = request.port.nil? ? '' : ":#{request.port}"
    url = "#{request.scheme}://#{request.host}#{port}/#{url_fragment}"
    return "<a href=\"#{url}\">#{path}</a>"
  end
end

get '/' do
  'Welcome.  Do stuff.'
end

get '/records' do
  @records = Record.all
  erb :index
end

bibs_url = 'https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs'

@@alma_key = ENV['ALMA_KEY']

get '/harvest/:bib_id' do |bib_id|
  return 'No key available' if @@alma_key.nil?
  blob = ''
  path = "#{bibs_url}/?mms_id=#{bib_id}&apikey=#{@@alma_key}"
  open(path) { |io| blob = io.read }
  blob = blob_with_holdings_call_number(blob) if params[:holdings_call_number]
  create_record(bib_id, blob) unless blob.empty?
end

get '/records/:bib_id' do |bib_id|
  content_type('text/xml')
  blob = Record.where(:bib_id => bib_id).pluck(:blob)
  return blob
end
