# Marmite

Marmite is an [ETL](https://www.webopedia.com/TERM/E/ETL.html) Sinatra application for creating and displaying harvestable metadata into various distillations for use by external services.

## Table of Contents

* [Requirements](#requirements)
* [Functionalities](#functionalities)
* [Development Setup](#development-setup)
* [Running the Test Suite](#running-the-test-suite)
* [API Version 2](#api-version-2)
* [Deployment](#deployment)
* [Contributing](#contributing)
* [License](#license)

## Requirements

* Ruby 2.6.x
* MySQL
* An Alma API key with read access to Bibs API sourced to the $ALMA_KEY environment variable.  Consult the [env.example](env.example) in this repository for an example.
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
* Visit [http://localhost:9292/](http://localhost:9292/harvesting) to learn available commands and endpoints.

### Stop Development/Test Environment
To stop the Lando containers: `rake marmite:stop`

### Remove (Clean) Containers
To remove Lando containers: `rake marmite:clean`

### Run interactive console
To start up a Rails-like console run: `bundle exec irb -r ./app/controllers/application_controller`

## Running the Test Suite
To set up test environment and run through test suite, run:
```
rake marmite:start
rspec
rake marmite:stop
```

## API Version 2
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

#### Body
JSON containing information necessary information to create IIIF manifest.

Example:
```json
{
  "id": "12349-0394", # Should match the identifier in the path
  "title": "An Amazing Item",
  "viewing_direction": "left-to-right",
  "viewing_hint": "individuals",
  "image_server": "http:/iiif.library.upenn.edu/iiif/2", # URL to Image Server
  "sequence": [
    {
      "label": "Page One",
      "file": "path/to/file/on/image/server.jpeg",
      "table_of_contents": [
        { "text": "First Illuminated Image" }
      ]
    }
  ]
}
```

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

## Deployment

### Environment Variables

Prior to building new images, ensure that an `.env` file is present in the `/root/deployments/marmite/` directory, and 
ensure that it contains any new or modified environment variables. The variables defined in this file will be present 
in the environment of the generated image.

### Dev/test

Development Marmite runs on `colenda-dev`. To deploy a new Marmite image:

```
  ssh username@colenda-dev
  sudo su
  cd /root/deployments/marmite/
  git pull (ensure you're pulling the desired branch)
  docker-compose pull (pull/update images referenced in docker-compose file)
  docker-compose up -d
```

### Production

Development Marmite runs on `mdproc`. To deploy a new Marmite image in production, use the instructions above.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://gitlab.library.upenn.edu/digital-repository/marmite/-/issues](https://gitlab.library.upenn.edu/digital-repository/marmite/-/issues).

## License

This code is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
