require 'sinatra'
require 'sinatra/json'
require 'sequel'
require 'json'
require 'uuid7'
require_relative 'lib/json_ld_converter'
require_relative 'lib/shacl_generator'

# Database connection
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/development.db')

# Models
class Frame < Sequel::Model
  one_to_many :frames_shacls
  many_to_many :shacls, join_table: :frames_shacls, left_key: :frame_id, right_key: :shacl_id
end

class Shacl < Sequel::Model
  one_to_many :frames_shacls
  many_to_many :frames, join_table: :frames_shacls, left_key: :shacl_id, right_key: :frame_id
end

class FramesShacl < Sequel::Model
  many_to_one :frame
  many_to_one :shacl
  unrestrict_primary_key
end

# Configure Sinatra
set :bind, '0.0.0.0'
set :port, 4567

# Helper methods
helpers do
  def parse_json_body
    request.body.rewind
    JSON.parse(request.body.read)
  rescue JSON::ParserError => e
    response['Content-Type'] = 'application/json'
    halt 400, { error: 'Invalid JSON', message: e.message }.to_json
  end

  def get_header(name)
    request.env["HTTP_#{name.upcase.gsub('-', '_')}"]
  end
end

# Routes

# Health check endpoint
get '/' do
  json({ 
    status: 'ok', 
    service: 'ld-shacl-bridge',
    version: '1.0.0'
  })
end

# Convert JSON to JSON-LD and generate SHACL
put '/convert' do
  content_type :json
  
  # Get headers
  context_header = get_header('Context')
  id_header = get_header('Id')
  
  # Validate headers
  unless context_header
    response['Content-Type'] = 'application/json'
    halt 400, { error: 'Missing Context header' }.to_json
  end
  unless id_header
    response['Content-Type'] = 'application/json'
    halt 400, { error: 'Missing Id header' }.to_json
  end
  
  # Parse JSON body
  json_data = parse_json_body
  
  begin
    # Convert to JSON-LD
    json_ld = JsonLdConverter.convert(json_data, context_header)
    
    # Generate SHACL shape
    shacl_shape = ShaclGenerator.generate(json_ld)
    
    # Generate UUID v7 for SHACL
    shacl_uuid = UUID7.generate
    
    # Store SHACL shape
    shacl_record = Shacl.create(
      shacl_id: shacl_uuid,
      shape: shacl_shape
    )
    
    # Store or find frame
    frame_record = Frame.find_or_create(frame_id: id_header) do |f|
      f.context = context_header
    end
    
    # Update frame context if it already exists
    if frame_record.context != context_header
      frame_record.update(context: context_header)
    end
    
    # Create many-to-many relationship
    FramesShacl.find_or_create(
      frame_id: frame_record.id,
      shacl_id: shacl_record.id
    )
    
    # Return JSON-LD with new @context and @id
    response_data = json_ld.merge({
      '@context' => "http://ld-shacl-bridge.org/shacl/#{shacl_uuid}",
      '@id' => "http://ld-shacl-bridge.org/frame/#{id_header}"
    })
    
    status 200
    json response_data
    
  rescue StandardError => e
    halt 500, json({ error: 'Internal server error', message: e.message })
  end
end

# Retrieve frame by ID
get '/frame/:id' do
  content_type :json
  
  frame = Frame.find(frame_id: params[:id])
  
  if frame
    # Get associated SHACL IDs
    shacl_ids = frame.shacls.map(&:shacl_id)
    
    json({
      frame_id: frame.frame_id,
      context: frame.context,
      shacl_ids: shacl_ids,
      created_at: frame.created_at
    })
  else
    halt 404, json({ error: 'Frame not found' })
  end
end

# Retrieve SHACL shape by ID
get '/shacl/:id' do
  content_type :json
  
  shacl = Shacl.find(shacl_id: params[:id])
  
  if shacl
    # Get associated frame IDs
    frame_ids = shacl.frames.map(&:frame_id)
    
    json({
      shacl_id: shacl.shacl_id,
      shape: shacl.shape,
      frame_ids: frame_ids,
      created_at: shacl.created_at
    })
  else
    halt 404, json({ error: 'SHACL shape not found' })
  end
end

# Error handlers
error 400 do
  content_type :json
  json({ error: 'Bad Request' })
end

error 404 do
  content_type :json
  json({ error: 'Not Found' })
end

error 500 do
  content_type :json
  json({ error: 'Internal Server Error' })
end
