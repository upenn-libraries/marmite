## README for marc_alma

Experiments with getting MARC data from Alma API with accurate call number from holdings, and structural metadata from SCETI endpoint.

So far contains a Sinatra app for harvesting and displaying marc21 and structural metadata.

## Installation
* Clone the repository.
* Run ```bundle install```.
* Run ```rake db:create && rake db:migrate```
* Run ```rackup```
* Visit ```/harvesting``` to learn available commands and endpoints.

## Requirements
* Ruby 2.4.0
* An Alma API key with read access to Bibs API sourced to the $ALMA_KEY environment variable.  Consult the [.env.example](env.example) in this repository for an aliasing example. 
