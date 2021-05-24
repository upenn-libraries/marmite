# README for `marmite`

Marmite is an [ETL](https://www.webopedia.com/TERM/E/ETL.html) Sinatra application for creating and displaying harvestable metadata into various distillations for use by external services.

## Table of contents

* [Requirements](#requirements)
* [Functionalities](#functionalities)
* [Development setup](#development-setup)
* [Running the Test Suite](#running-the-test-suite)
* [Production setup](#production-setup)
* [Contributing](#contributing)
* [License](#license)


## Requirements

* Ruby 2.6.x
* MySQL
* An Alma API key with read access to Bibs API sourced to the $ALMA_KEY environment variable.  Consult the [alias.example](alias.example) in this repository for an aliasing example.
* Docker for production and docker-compose version 2 or higher

## Functionalities

The application makes the following XML metadata formats available:

* `marc21` - descriptive metadata transformed from Alma bib and holdings XML payloads, with minor term transformations and fixes for ease of machine processing
* `structural` - structural metadata transformed from dla structural XML payloads, in [Bulwark](https://github.com/upenn-libraries/bulwark)-compliant format
* `openn` - descriptive and structural metadata in a single payload, in the format used by the OPenn package generation tools
* `iiif_presentation` - IIIF presentation 2.0 manifests

## Development Setup
### Initial Setup

* Clone the repository
* Install necessary gems by running `bundle install`
* Install Lando following instructions here: https://docs.lando.dev/basics/installation.html#system-requirements

### Start Development/Test Environment
* Build development/test containers via Lando, run: `rake marmite:start`
* Run `rackup` to start the application
* Visit [http://localhost:9292/harvesting](http://localhost:9292/harvesting) to learn available commands and endpoints.

### Stop Development/Test Environment
To stop the Lando containers: `rake marmite:stop`

### Remove (Clean) Containers
To remove Lando containers: `rake marmite:clean`

## Running the Test Suite
To set up test environment and run through test suite, run:
```
rake marmite:start
rspec
rake marmite:stop
```

## API Version 2 Spec
Namespace API requests: api/v2

GET `/api/v2/records/:bib_id/:format`
  - This request creates a record for the bib_id and format combination, if its not already present. If a record is already present, it does not update it unless this is requested via the update parameter.  
  - Note: `structural` never needs to be refreshed, refresh params can be ignored
  - Request
    - parameters (within request)
      - `bib_id`: a records bibid, either the long or short format
      - `format`: xml metadata formats
        - valid formats: openn, marc21, structural, iiif_presentation
    - query params
      - `update`
       - `always`: explicitly refresh record always, refreshes the record (aka. recreates the record, when appropriate) 
       - `never`: explicitly don't refresh the record
       - `{number}`: conditionally refresh the record, refreshes record when the last modification is older than the number of hours given
  - Response
    - Successful response 
      - body: xml for everything but, iiif_presentation, which is json
      - headers
        - last modified
        - created at
      - status
          - `200` if record was not recreated
          - `201` if record is created or updated
    - Error response:
      - body: `{ errors: [{ "message": "" }, { "message": "" }]}`
      - format: json
      - status
        - `404` if bibid is not valid
        -  `500` if error creating metadata
  
### Get IIIF Presentation Manifest
Retrieves IIIF Presentation Manifest for given identifier.

`GET /api/v2/records/:id/iiif_presentation`

#### Parameters

| Name | In | Description |
| ---- | -- | ----------- |
| id   | path | identifier for iiif manifest |

#### Default Response
`Status: 200 OK`

```
{ INSERT IIIF MANIFEST }
```
#### Resource Not Found
`Status: 404 NOT FOUND`

```json
{
  "errors": ["Record not found."]
}
```

### Create IIIF Presentation Manifest
Create IIIF Presentation v2 Manifest using the data given in the body of the request.

`POST /api/v2/records/:id/iiif_presentation`

#### Parameters
| Name | In | Description |
| ---- | -- | ----------- |
| id   | path | identifier for iiif manifest |
| body | | |

#### Default Response
`Status: 201 CREATED`

`{ Insert IIIF Manifest here }`

#### Validation Failed (Missing information in request body)
`Status: 422 Unprocessable Entity`

```json
{
  "errors": ["Unexpected error generating IIIF manifest."]
}
```




### GET IIIF Presentation Manifest

## Production setup

* Clone the repository.

  Ensure that the image tag in the `docker-compose.yml` matches the version of the image from [Quay.io](https://quay.io/repository/upennlibraries/marmite?tag=latest&tab=tags) that you want to deploy.

* Copy `.env.example` into a file alongside it called `.env`.

* Populate the new file with the appropriate values, including a valid Alma API key.

* Run `docker-compose up -d`

## Deployment workflow

This illustration represents the current deployment workflow for marmite.

![Marmite deployment workflow](marmite_deployment.png)
## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/upenn-libraries/marmite](https://github.com/upenn-libraries/marmite).

## License

This code is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
