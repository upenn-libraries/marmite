# Marmite

Marmite is an [ETL](https://www.webopedia.com/TERM/E/ETL.html) Sinatra application for creating and displaying harvestable metadata into various distillations for use by external services.

## Table of Contents

* [Requirements](#requirements)
* [Functionalities](#functionalities)
* [API Version 2](#api-version-2)
  * [Get MARC21 XML](#get-marc21-xml)
  * [Get Structural Metadata XML](#get-structural-metadata-xml)
  * [Get IIIF Presentation Manifest](#get-iiif-presentation-manifest)
  * [Create IIIF Presentation Manifest](#create-iiif-presentation-manifest)
* [Development Setup](#development-setup)
* [Running the Test Suite](#running-the-test-suite)
* [Rubocop](#rubocop)
* [Deployment](#deployment)
* [Contributing](#contributing)
* [License](#license)

## Requirements

* Ruby 2.6.x
* MySQL
* An Alma API key with read access to Bibs API sourced to the $ALMA_KEY environment variable.  Consult the [env.example](env.example) in this repository for an example.
* Docker for production and docker-compose version 2 or higher

## Functionalities

The application makes the following metadata formats available:

| format | mime_type | description |
| ------ |-----------| ----------- |
| `marc21` | XML       | descriptive metadata transformed from Alma bib and holdings XML payloads, with minor term transformations and fixes for ease of machine processing |
| `structural` | XML       | structural metadata transformed from dla structural XML payloads, in [Bulwark](https://github.com/upenn-libraries/bulwark)-compliant format |
| `iiif_presentation` | JSON      | IIIF presentation 2.0 manifests |

## API Version 2
RESTful API to query for all available metadata formats. This API should be preferred over the previous endpoints. All request to this API are namespaced under `api/v2`.
  
### Get MARC21 XML
Retrieves MARC XML from database cache, updating the cache if requested.
#### Request
```
GET /api/v2/records/:bib_id/marc21
```
- **Path Parameter**
  - `bib_id`: record's identifier (long or short format), required
- **Query Parameter**
  - `update`: updates or doesn't update record based on the value provided, optional, valid values are:
       - `always`: explicitly refresh record
       - `never`: explicitly don't refresh the record
       - `{number}`: refreshes record when the last modification is older than the number of hours given

#### Responses
- **Successfully Creates or Updates Record**
  - Status: `201 Created`
  - Content Type: `text/xml`
  - Body:
    ```xml
    { INSERT MARC XML }
    ```
- **Successfully Retrieves Record**
  - Status: `200 OK`
  - Content Type: `text/xml`
  - Body:
    ```xml
    { INSERT MARC XML }
    ```
- **Record Not Found**
  - Status: `404 Not Found`
  - Content Type: `application/json`
  - Body: 
    ```json
     { "errors": ["Bib not found in Alma for {INSERT BIB_ID HERE}"]}
    ```
- **Error in Processing**
  - Status: `500 Internal Server Error`
  - Content Type: `application/json`
  - Body:
    ```json
    { "errors": ["MARC transformation error: 1:1: FATAL: Start tag expected, '\u003c' not found"] }
    ```

### Get Structural Metadata XML
Retrieves structural metadata for the given bib_id either from the database cache or from the remote source. This structural metadata is no longer changing, therefore once its retrieved once it doesn't need to be updated. If a short bibnumber is provided, it is expanded and the xml returned will only reference the long bibnumber.

#### Request
```
GET /api/v2/records/:bib_id/structural
```
- **Path Parameter**
  - `bib_id`: record's identifier (long or short format), required

#### Responses
- **Successfully Creates Record**
  - Status: `201 Created`
  - Content Type: `text/xml`
  - Body:
    ```
    { INSERT STRUCTURAL XML }
    ```
- **Successfully Retrieves Record**
  - Status: `200 OK`
  - Content Type: `text/xml`
  - Body:
    ```
    { INSERT STRUCTURAL XML }
    ```
- **Record Not Found**
  - Status: `404 Not Found`
  - Content Type: `application/json`
  - Body:
    ```json
    { "errors": ["Record not found."] }
    ```

### Get IIIF Presentation Manifest
Retrieves IIIF Presentation Manifest for given identifier.

#### Request
```
GET /api/v2/records/:id/iiif_presentation
```
- **Path Parameters**
  - `id`: identifier for iiif manifest, required

#### Responses
- **Successful** 
  - Status: `200 OK`
  - Content Type: `text/xml`
  - Body:
    ```
    { INSERT IIIF MANIFEST }
    ```
- **Resource Not Found**
  - Status: `404 Not Found`
  - Content Type: `application/json`
  - Body: 
    ```json
    { "errors": ["Record not found."] }
    ```

### Create IIIF Presentation Manifest
Saves the IIIF Presentation v2 Manifest provided in the POST body.

#### Request
```
POST /api/v2/records/:id/iiif_presentation
```

- **Path Parameters**
  - `id`: identifier for iiif manifest, required
- **Body**
  - JSON containing information necessary information to create IIIF manifest.
  - Required
  - Example:
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

#### Responses
- **Successful**
  - Status: `201 Created`
  - Content Type: `application/json`
  - Body: 
    ```
    { Insert IIIF Manifest here }
    ```
- **Validation Failed (Missing information in request body)**
  - Status: `500 Internal Server Error`
  - Content Type: `application/json`
  - Body:
    ```json
    {
       "errors": ["Unexpected error generating IIIF manifest."]
    }
    ```

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

## Rubocop

This application uses Rubocop to enforce Ruby and Rails style guidelines. We centralize our UPenn specific configuration in
[upennlib-rubocop](https://gitlab.library.upenn.edu/digital-library-development-team/upennlib-rubocop).

If there are rubocop offenses that you are not able to fix please do not edit the rubocop configuration instead regenerate the `rubocop_todo.yml` using the following command:

```bash
rubocop --auto-gen-config  --auto-gen-only-exclude --exclude-limit 10000
```

To change our default Rubocop config please open an MR in the `upennlib-rubocop` project.

## Deployment

To deploy Marmite:
1. Create versioned tag in Gitlab via a [GitLab Release](https://gitlab.library.upenn.edu/digital-repository/marmite/-/releases). Versioned tags should follow [Semantic Versioning](https://semver.org/).
2. Update the image tag in the `docker-compose.yml` on `main` via a [new merge request](https://gitlab.library.upenn.edu/digital-repository/marmite/-/merge_requests/new).
3. Wait for image to be created via [CI/CD pipeline](https://gitlab.library.upenn.edu/digital-repository/marmite/-/pipelines). Check that an image for the tagged release is available in the [container registry](https://gitlab.library.upenn.edu/digital-repository/marmite/container_registry).
4. SSH into deployment server and go to deployment directory. Development Marmite runs on `colenda-dev`. Production Marmite runs on `mdproc`.
   ```
   ssh username@server
   sudo su
   cd /root/deployments/marmite/
   ```
5. Ensure that an `.env` file is present in the `/root/deployments/marmite/` directory, and 
ensure that it contains any new or modified environment variables. The variables defined in this file will be present 
in the environment of the generated image.
6. Update `main` branch on deployment server
   ```
   git pull
   ```
7. Deploy application containers via docker-compose
   ```
   docker-compose pull (pull/update images referenced in docker-compose file)
   docker-compose up -d
   ```

## Contributing

Bug reports and pull requests are welcome on GitLab at [https://gitlab.library.upenn.edu/digital-repository/marmite/-/issues](https://gitlab.library.upenn.edu/digital-repository/marmite/-/issues).

## License

This code is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
