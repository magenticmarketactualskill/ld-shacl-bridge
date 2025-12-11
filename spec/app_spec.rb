require_relative 'spec_helper'

RSpec.describe 'ld-shacl-bridge API' do
  describe 'GET /' do
    it 'returns health check status' do
      get '/'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['service']).to eq('ld-shacl-bridge')
    end
  end

  describe 'PUT /convert' do
    let(:json_data) do
      {
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'age' => 30
      }
    end

    let(:context_url) { 'https://schema.org/' }
    let(:frame_id) { 'test-frame-1' }

    context 'with valid JSON and headers' do
      it 'converts JSON to JSON-LD and returns response' do
        put '/convert',
            json_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url,
              'HTTP_ID' => frame_id }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        
        expect(json['@context']).to match(/http:\/\/ld-shacl-bridge\.org\/shacl\//)
        expect(json['@id']).to eq("http://ld-shacl-bridge.org/frame/#{frame_id}")
        expect(json['name']).to eq('John Doe')
      end

      it 'stores frame in database' do
        put '/convert',
            json_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url,
              'HTTP_ID' => frame_id }

        frame = Frame.find(frame_id: frame_id)
        expect(frame).not_to be_nil
        expect(frame.context).to eq(context_url)
      end

      it 'stores SHACL shape in database' do
        put '/convert',
            json_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url,
              'HTTP_ID' => frame_id }

        expect(Shacl.count).to eq(1)
        shacl = Shacl.first
        expect(shacl.shape).to include('sh:NodeShape')
      end

      it 'creates many-to-many relationship' do
        put '/convert',
            json_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url,
              'HTTP_ID' => frame_id }

        frame = Frame.find(frame_id: frame_id)
        expect(frame.shacls.count).to eq(1)
      end
    end

    context 'with JSON-LD input (already has @context)' do
      let(:json_ld_data) do
        {
          '@context' => 'https://schema.org/',
          'name' => 'Jane Doe',
          'email' => 'jane@example.com'
        }
      end

      it 'processes JSON-LD correctly' do
        put '/convert',
            json_ld_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url,
              'HTTP_ID' => 'test-frame-2' }

        expect(last_response).to be_ok
        json = JSON.parse(last_response.body)
        expect(json['name']).to eq('Jane Doe')
      end
    end

    context 'without Context header' do
      it 'returns 400 error' do
        put '/convert',
            json_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_ID' => frame_id }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json['error']).to match(/Missing Context header|Bad Request/)
      end
    end

    context 'without Id header' do
      it 'returns 400 error' do
        put '/convert',
            json_data.to_json,
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json['error']).to match(/Missing Id header|Bad Request/)
      end
    end

    context 'with invalid JSON' do
      it 'returns 400 error' do
        put '/convert',
            'invalid json',
            { 'CONTENT_TYPE' => 'application/json',
              'HTTP_CONTEXT' => context_url,
              'HTTP_ID' => frame_id }

        expect(last_response.status).to eq(400)
        json = JSON.parse(last_response.body)
        expect(json['error']).to match(/Invalid JSON|Bad Request/)
      end
    end
  end

  describe 'GET /frame/:id' do
    let(:frame_id) { 'test-frame-retrieve' }
    let(:context_url) { 'https://schema.org/' }

    before do
      # Create a frame with associated SHACL
      frame = Frame.create(frame_id: frame_id, context: context_url)
      shacl = Shacl.create(shacl_id: UUID7.generate, shape: 'test shape')
      FramesShacl.create(frame_id: frame.id, shacl_id: shacl.id)
    end

    it 'retrieves frame by ID' do
      get "/frame/#{frame_id}"
      
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['frame_id']).to eq(frame_id)
      expect(json['context']).to eq(context_url)
      expect(json['shacl_ids']).to be_an(Array)
      expect(json['shacl_ids'].length).to eq(1)
    end

    it 'returns 404 for non-existent frame' do
      get '/frame/non-existent'
      
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to match(/Frame not found|Not Found/)
    end
  end

  describe 'GET /shacl/:id' do
    let(:shacl_id) { UUID7.generate }
    let(:shape_content) { '@prefix sh: <http://www.w3.org/ns/shacl#> .' }

    before do
      # Create a SHACL with associated frame
      shacl = Shacl.create(shacl_id: shacl_id, shape: shape_content)
      frame = Frame.create(frame_id: 'test-frame', context: 'https://schema.org/')
      FramesShacl.create(frame_id: frame.id, shacl_id: shacl.id)
    end

    it 'retrieves SHACL shape by ID' do
      get "/shacl/#{shacl_id}"
      
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['shacl_id']).to eq(shacl_id)
      expect(json['shape']).to eq(shape_content)
      expect(json['frame_ids']).to be_an(Array)
      expect(json['frame_ids'].length).to eq(1)
    end

    it 'returns 404 for non-existent SHACL' do
      get '/shacl/non-existent'
      
      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to match(/SHACL shape not found|Not Found/)
    end
  end
end

RSpec.describe JsonLdConverter do
  describe '.convert' do
    it 'adds @context to plain JSON' do
      json = { 'name' => 'Test' }
      context = 'https://schema.org/'
      result = JsonLdConverter.convert(json, context)
      
      expect(result['@context']).to eq(context)
      expect(result['name']).to eq('Test')
    end

    it 'preserves existing @context in JSON-LD' do
      json_ld = { '@context' => 'https://example.org/', 'name' => 'Test' }
      result = JsonLdConverter.convert(json_ld, 'https://schema.org/')
      
      expect(result['@context']).to eq('https://example.org/')
    end
  end

  describe '.json_ld?' do
    it 'returns true for JSON-LD' do
      json_ld = { '@context' => 'https://schema.org/' }
      expect(JsonLdConverter.json_ld?(json_ld)).to be true
    end

    it 'returns false for plain JSON' do
      json = { 'name' => 'Test' }
      expect(JsonLdConverter.json_ld?(json)).to be false
    end
  end
end

RSpec.describe ShaclGenerator do
  describe '.generate' do
    it 'generates SHACL shape from JSON-LD' do
      json_ld = {
        '@context' => 'https://schema.org/',
        '@id' => 'https://example.org/person/1',
        'name' => 'John Doe',
        'email' => 'john@example.com'
      }
      
      shape = ShaclGenerator.generate(json_ld)
      
      expect(shape).to include('sh:NodeShape')
      expect(shape).to include('sh:property')
    end
  end
end
