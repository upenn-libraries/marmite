require 'addressable'
require 'faraday'
require 'faraday/net_http'
require 'iiif/presentation'
require 'active_support/core_ext/numeric/conversions'

class IIIFPresentation
  class MissingArgument < ArgumentError
    def initialize(variable_name)
      super("Missing #{variable_name}")
    end
  end

  attr_reader :id, :title, :viewing_direction, :viewing_hint, :assets, :image_server

  def initialize(data)
    data.deep_symbolize_keys!

    @id                = data[:id]
    @title             = data[:title]
    @viewing_direction = data[:viewing_direction]
    @viewing_hint      = data[:viewing_hint]
    @assets            = data[:sequence] || []
    @image_server      = data[:image_server]

    raise MissingArgument.new('id') unless id
    raise MissingArgument.new('title') unless title
    raise MissingArgument.new('image_server') unless image_server
    raise MissingArgument.new('sequence') if assets.empty?
  end

  # Generate IIIF Presentation 2.0 manifest
  def manifest
    seed = { 'label' => title }

    manifest = IIIF::Presentation::Manifest.new(seed)

    manifest['@id'] = uri(image_server, "#{id}/manifest")
    manifest.attribution = 'University of Pennsylvania Libraries'
    manifest.viewing_hint = viewing_hint
    manifest.viewing_direction = viewing_direction

    sequence = IIIF::Presentation::Sequence.new(
      '@id' => uri(image_server, "#{id}/sequence/normal"),
      'label' => 'Current order'
    )

    assets.map.with_index do |asset, i|
      index = i + 1

      # Retrieve image information from image server
      url = uri(image_server, "#{asset[:file]}/info.json")
      info = JSON.parse(Faraday.get(URI.parse(url)).body)

      # Adding canvas that contains image as an image annotation.
      sequence.canvases << canvas(
        index: index,
        label: asset[:label],
        height: info['height'],
        width: info['width'],
        profile: info['profile'][0],
        filepath: asset[:file],
        additional_downloads: asset[:additional_downloads]
      )

      # Adding table of contents, if label and table of contents entries are provided.
      if asset[:label] && asset[:table_of_contents]&.any?
        manifest.structures << range(
          index: index,
          label: asset[:label],
          table_of_contents: asset[:table_of_contents]
        )
      end
    end

    manifest.sequences << sequence
    manifest.to_json
  end

  private

  # Returns canvas with one annotated image. The canvas and image size are the same.
  #
  # @param index [Integer] canvas number, used to create identifiers
  # @param width [Integer] image width
  # @param height [Integer] image height
  # @param profile [String] uri for IIIF image profile image server uses
  # @param label [String] label for image
  # @param filepath [String] filepath for image
  # @param additional_downloads [Array<Hash>] information describing additional downloads
  def canvas(index:, width:, height:, profile:, label: nil, filepath:, additional_downloads: nil)
    canvas = IIIF::Presentation::Canvas.new
    canvas['@id'] = uri(image_server, "#{id}/canvas/p#{index}")
    canvas.label  = label || "p. #{index}"
    canvas.height = height
    canvas.width  = width

    annotation = IIIF::Presentation::Annotation.new

    # By providing width, height and profile, we avoid the IIIF gem fetching the data again.
    annotation.resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(
      service_id: uri(image_server, filepath), width: width, height: height, profile: profile,
    )
    annotation['on'] = canvas['@id']

    canvas.images << annotation

    if additional_downloads
      canvas['rendering'] = additional_downloads.map { |download_info| rendering(download_info) }
    end

    canvas
  end

  def rendering(link:, label:, format:, size: nil)
    {
      "@id" => link,
      "label" => size ? "#{label} - #{size.to_s(:human_size)}" : label,
      "format" => format
    }
  end

  # Returns range with sub ranges for each table of contents entry. For each table of contents entry will
  # point to the entire canvas.
  #
  # Note: If at some point coordinates are provided for each table of contents entry we can point directly
  # to the coordinates given.
  #
  # @param index [Integer] range number, used to create identifiers
  # @param label [String]
  # @param table_of_contents [Array<Hash>] list of table of contents entry
  def range(index:, label:, table_of_contents:)
    subranges = table_of_contents.map.with_index do |entry, subrange_index|
      IIIF::Presentation::Range.new(
        '@id' => uri(image_server, "#{id}/range/r#{index}-#{subrange_index + 1}"),
        'label' => entry[:text],
        'canvases' => [uri(image_server, "#{id}/canvas/p#{index}")]
      )
    end

    IIIF::Presentation::Range.new(
      '@id' => uri(image_server, "#{id}/range/r#{index}"),
      'label' => label,
      'ranges' => subranges
    )
  end

  def uri(server_url, path)
    # Add trailing slash to url.
    server_url = "#{server_url}/" unless server_url.end_with?('/')

    Addressable::URI.join(server_url, path).to_s
  end
end
