require 'rdf'
require 'rdf/turtle'
require 'json/ld'

module ShaclGenerator
  SHACL = RDF::Vocabulary.new('http://www.w3.org/ns/shacl#')
  XSD = RDF::Vocabulary.new('http://www.w3.org/2001/XMLSchema#')
  RDF_TYPE = RDF.type

  class << self
    # Generate SHACL shape from JSON-LD
    # @param json_ld [Hash] The JSON-LD document
    # @return [String] The SHACL shape in Turtle format
    def generate(json_ld)
      graph = RDF::Graph.new
      
      # Convert JSON-LD to RDF graph to analyze structure
      rdf_graph = JsonLdConverter.to_rdf_graph(json_ld)
      
      # Extract unique predicates and their object types
      property_info = analyze_properties(rdf_graph)
      
      # Create a NodeShape
      shape_uri = RDF::URI.new("http://ld-shacl-bridge.org/shapes/NodeShape")
      
      # Add sh:NodeShape type
      graph << [shape_uri, RDF_TYPE, SHACL.NodeShape]
      
      # Add property shapes for each predicate
      property_info.each_with_index do |(predicate, info), index|
        property_shape = RDF::Node.new("property_#{index}")
        
        graph << [shape_uri, SHACL.property, property_shape]
        graph << [property_shape, SHACL.path, predicate]
        
        # Add datatype constraint if applicable
        if info[:datatype]
          graph << [property_shape, SHACL.datatype, info[:datatype]]
        end
        
        # Add minCount constraint (at least 1)
        graph << [property_shape, SHACL.minCount, RDF::Literal.new(1)]
        
        # Add class constraint if it's an object property
        if info[:node_kind] == :IRI
          graph << [property_shape, SHACL.nodeKind, SHACL.IRI]
        elsif info[:node_kind] == :Literal
          graph << [property_shape, SHACL.nodeKind, SHACL.Literal]
        end
      end
      
      # Serialize to Turtle format
      graph.dump(:turtle, prefixes: {
        sh: SHACL.to_uri.to_s,
        xsd: XSD.to_uri.to_s,
        rdf: RDF.to_uri.to_s
      })
    end

    private

    # Analyze RDF graph to extract property information
    # @param graph [RDF::Graph] The RDF graph
    # @return [Hash] Property information
    def analyze_properties(graph)
      properties = {}
      
      graph.each_statement do |statement|
        predicate = statement.predicate
        object = statement.object
        
        # Skip RDF type statements for now
        next if predicate == RDF_TYPE
        
        properties[predicate] ||= { datatype: nil, node_kind: nil }
        
        if object.literal?
          properties[predicate][:node_kind] = :Literal
          properties[predicate][:datatype] = object.datatype if object.datatype
        elsif object.uri?
          properties[predicate][:node_kind] = :IRI
        end
      end
      
      properties
    end
  end
end
