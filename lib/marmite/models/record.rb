require 'sinatra/activerecord'

class Record < ActiveRecord::Base

  FORMATS_TO_ALWAYS_RECREATE = %w[structural_ark combined_ark iiif_presentation]

  @error_message = ''

  def self.error_message
    @error_message
  end

  def self.error_message=(value)
    @error_message = value
  end

  # A record is fresh if it is:
  # - NOT one of the FORMATS_TO_ALWAYS_RECREATE
  # OR
  # - less than 1 day old
  # @return [TrueClass, FalseClass]
  def fresh?
    return false if FORMATS_TO_ALWAYS_RECREATE.include?(format)

    return false unless updated_at # new record

    current_time = Time.now.gmtime
    yesterday = current_time - 1.day
    (yesterday..current_time).cover?(Time.at(updated_at).gmtime)
  end
end
