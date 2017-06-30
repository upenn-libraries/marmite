## README for marc_alma

Experiments with getting MARC data from Alma API with accurate call number from holdings, and structural metadata from SCETI endpoint.

So far contains a Sinatra app for harvesting and displaying marc21 and structural metadata.

## Installation
* Clone the repository.
* Run ```bundle install```.
* Run ```rake db:create && rake db:migrate```
* Run ```rackup```
* Visit [http://localhost:9292/harvesting](http://localhost:9292/harvesting) to learn available commands and endpoints.

## Requirements
* Ruby 2.4.0
* An Alma API key with read access to Bibs API sourced to the $ALMA_KEY environment variable.  Consult the [env.example](env.example) in this repository for an aliasing example. 

## Example Bib IDs
* 9957001503503681 
   * accurate call number value in the MARCL XML 099a field
* 9949529953503681
  * inaccurate call number value in the MARC XML 099a field; pull from holdings information instead. Should be "Oversize LJS 63" if the application is functioning.
* 9932421043503681
  * from Print at Penn, no 099 value