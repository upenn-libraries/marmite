require 'sinatra/activerecord'

class Record < ActiveRecord::Base

  @error_message = ''

  def self.error_message
    @error_message
  end

  def self.error_message=(value)
    @error_message = value
  end
end
