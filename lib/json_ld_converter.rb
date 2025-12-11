require 'json/ld'
require 'rdf'

module JsonLdConverter
  class << self
    # Convert JSON to JSON-LD
    # @param json_data [Hash] The input JSON data
    # @param context_url [String] The JSON-LD context URL
    # @return [Hash] The JSON-LD document
    def convert(json_data, context_url)
      # Check if the JSON already has a @context
      if json_data.key?('@context')
        # Already JSON-LD, return as-is
        json_data
      else
        # Add the context to convert to JSON-LD
        json_data.merge('@context' => context_url)
      end
    end

    # Check if JSON is already JSON-LD
    # @param json_data [Hash] The input JSON data
    # @return [Boolean] True if the JSON has @context
    def json_ld?(json_data)
      json_data.is_a?(Hash) && json_data.key?('@context')
    end

    # Expand JSON-LD to RDF graph
    # @param json_ld [Hash] The JSON-LD document
    # @return [RDF::Graph] The expanded RDF graph
    def to_rdf_graph(json_ld)
      graph = RDF::Graph.new
      JSON::LD::API.toRdf(json_ld) do |statement|
        graph << statement
      end
      graph
    end
  end
end
