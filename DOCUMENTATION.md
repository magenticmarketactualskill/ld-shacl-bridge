# ld-shacl-bridge: Complete Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [API Reference](#api-reference)
5. [Implementation Details](#implementation-details)
6. [Testing](#testing)
7. [Deployment](#deployment)

## Overview

The **ld-shacl-bridge** application is a Ruby Sinatra web service that bridges the gap between plain JSON and the Semantic Web by providing automatic conversion to JSON-LD and generating SHACL (Shapes Constraint Language) shapes for validation.

### Key Features

The application provides three core functionalities:

1. **JSON to JSON-LD Conversion**: Accepts plain JSON and converts it to JSON-LD using a provided context URL.
2. **SHACL Shape Generation**: Automatically generates SHACL constraint shapes by analyzing the structure of the JSON-LD data.
3. **Frame and SHACL Management**: Stores frames (JSON-LD contexts with identifiers) and their associated SHACL shapes in a many-to-many relationship.

### Use Cases

- **Data Validation**: Generate SHACL shapes for validating incoming JSON data against expected structures.
- **Semantic Web Integration**: Convert existing JSON APIs to JSON-LD for better interoperability.
- **Schema Management**: Maintain a library of data shapes and their associated contexts.

## Architecture

### System Components

The application follows a modular architecture with clear separation of concerns:

#### 1. Web Layer (Sinatra Application)

The main application (`app.rb`) handles HTTP requests and responses. It provides three primary endpoints:

- `PUT /convert`: Main conversion endpoint
- `GET /frame/:id`: Frame retrieval endpoint
- `GET /shacl/:id`: SHACL shape retrieval endpoint

#### 2. Conversion Layer

**JsonLdConverter Module** (`lib/json_ld_converter.rb`)

This module handles the conversion of plain JSON to JSON-LD. It provides:

- Detection of existing JSON-LD (checking for `@context`)
- Context injection for plain JSON
- RDF graph conversion for further processing

#### 3. SHACL Generation Layer

**ShaclGenerator Module** (`lib/shacl_generator.rb`)

This module analyzes JSON-LD structure and generates SHACL shapes. The process involves:

1. Converting JSON-LD to an RDF graph
2. Analyzing properties and their datatypes
3. Creating SHACL NodeShape with property constraints
4. Serializing to Turtle format

#### 4. Data Layer

**Database Models**

The application uses Sequel ORM with three models:

- **Frame**: Stores frame identifiers and contexts
- **Shacl**: Stores SHACL shapes with UUID v7 identifiers
- **FramesShacl**: Join table implementing many-to-many relationship

### Database Schema

The database schema supports the many-to-many relationship between frames and SHACL shapes:

```
frames
├── id (PK)
├── frame_id (UNIQUE)
├── context
└── created_at

shacls
├── id (PK)
├── shacl_id (UNIQUE, UUID v7)
├── shape (TEXT, Turtle format)
└── created_at

frames_shacls
├── frame_id (FK → frames.id)
└── shacl_id (FK → shacls.id)
```

### Workflow

The conversion workflow follows these steps:

1. **Request Reception**: Client sends PUT request to `/convert` with JSON payload and headers
2. **Validation**: Headers (Context and Id) are validated
3. **JSON Parsing**: Request body is parsed as JSON
4. **Conversion**: JSON is converted to JSON-LD using the provided context
5. **SHACL Generation**: A SHACL shape is generated from the JSON-LD structure
6. **UUID Generation**: A UUID v7 is generated for the SHACL shape
7. **Storage**: Both frame and SHACL are stored in the database
8. **Relationship Creation**: Many-to-many relationship is established
9. **Response**: JSON-LD is returned with new `@context` and `@id` pointing to stored resources

## Installation

### Prerequisites

- Ruby 3.3.6 (managed via rbenv or similar)
- SQLite 3
- Bundler gem

### Setup Steps

1. **Extract the application**:
```bash
unzip ld-shacl-bridge.zip
cd ld-shacl-bridge
```

2. **Install Ruby dependencies**:
```bash
bundle install
```

3. **Set up the database**:
```bash
bundle exec rake db:migrate
```

4. **Verify installation**:
```bash
bundle exec rspec
```

All 18 tests should pass.

## API Reference

### Endpoint: Health Check

```
GET /
```

**Description**: Returns the service status and version information.

**Response**: 200 OK
```json
{
  "status": "ok",
  "service": "ld-shacl-bridge",
  "version": "1.0.0"
}
```

### Endpoint: Convert JSON to JSON-LD

```
PUT /convert
```

**Description**: Converts JSON to JSON-LD, generates SHACL shape, and stores both.

**Headers**:
- `Context` (required): JSON-LD context URL
- `Id` (required): Unique identifier for the frame

**Request Body**: JSON object

**Example Request**:
```bash
curl -X PUT http://localhost:4567/convert \
  -H "Content-Type: application/json" \
  -H "Context: https://schema.org/" \
  -H "Id: person-frame-1" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30
  }'
```

**Success Response**: 200 OK
```json
{
  "@context": "http://ld-shacl-bridge.org/shacl/01JEMXXX...",
  "@id": "http://ld-shacl-bridge.org/frame/person-frame-1",
  "name": "John Doe",
  "email": "john@example.com",
  "age": 30
}
```

**Error Responses**:
- 400 Bad Request: Missing headers or invalid JSON
- 500 Internal Server Error: Processing error

### Endpoint: Retrieve Frame

```
GET /frame/:id
```

**Description**: Retrieves a stored frame by its identifier.

**Parameters**:
- `id`: Frame identifier (from Id header during creation)

**Example Request**:
```bash
curl http://localhost:4567/frame/person-frame-1
```

**Success Response**: 200 OK
```json
{
  "frame_id": "person-frame-1",
  "context": "https://schema.org/",
  "shacl_ids": ["01JEMXXX..."],
  "created_at": "2024-12-11T13:20:00.000Z"
}
```

**Error Response**: 404 Not Found
```json
{
  "error": "Frame not found"
}
```

### Endpoint: Retrieve SHACL Shape

```
GET /shacl/:id
```

**Description**: Retrieves a stored SHACL shape by its UUID.

**Parameters**:
- `id`: SHACL UUID (from response `@context` during creation)

**Example Request**:
```bash
curl http://localhost:4567/shacl/01JEMXXX...
```

**Success Response**: 200 OK
```json
{
  "shacl_id": "01JEMXXX...",
  "shape": "@prefix sh: <http://www.w3.org/ns/shacl#> .\n...",
  "frame_ids": ["person-frame-1"],
  "created_at": "2024-12-11T13:20:00.000Z"
}
```

**Error Response**: 404 Not Found
```json
{
  "error": "SHACL shape not found"
}
```

## Implementation Details

### JSON-LD Conversion

The `JsonLdConverter` module provides a simple but effective conversion strategy:

1. **Detection**: Checks if the input JSON already contains an `@context` key
2. **Injection**: If no context exists, merges the provided context URL into the JSON
3. **Preservation**: If context exists, the original JSON-LD is preserved

This approach ensures that both plain JSON and existing JSON-LD can be processed.

### SHACL Generation

The `ShaclGenerator` module implements a basic SHACL shape generation algorithm:

1. **RDF Conversion**: Converts JSON-LD to an RDF graph using the json-ld gem
2. **Property Analysis**: Iterates through RDF statements to identify properties
3. **Type Detection**: Determines if properties are literals or IRIs
4. **Constraint Creation**: Generates `sh:property` constraints for each property
5. **Serialization**: Outputs the SHACL shape in Turtle format

The generated shapes include:
- `sh:NodeShape` as the base shape
- `sh:property` for each detected property
- `sh:path` specifying the property path
- `sh:minCount` set to 1 (required property)
- `sh:datatype` for literal properties
- `sh:nodeKind` for type constraints

### UUID Generation

The application uses UUID version 7 for SHACL identifiers. UUID v7 provides:
- Time-ordered identifiers
- Better database indexing performance
- Sortable by creation time

### Many-to-Many Relationship

The database design supports scenarios where:
- One frame can be associated with multiple SHACL shapes (e.g., versioning)
- One SHACL shape can be shared by multiple frames (e.g., common structures)

This flexibility allows for efficient storage and reuse of SHACL shapes.

## Testing

### Test Suite

The application includes comprehensive RSpec tests covering:

1. **Endpoint Tests**:
   - Health check functionality
   - Conversion with valid and invalid inputs
   - Frame retrieval (success and not found)
   - SHACL retrieval (success and not found)

2. **Module Tests**:
   - JSON-LD conversion logic
   - JSON-LD detection
   - SHACL generation

3. **Integration Tests**:
   - Database storage
   - Many-to-many relationships
   - Error handling

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with detailed output
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/app_spec.rb
```

### Test Database

Tests use a separate SQLite database (`db/test.db`) which is automatically:
- Created before tests run
- Cleaned between test cases
- Isolated from development data

## Deployment

### Production Considerations

1. **Database**: Consider migrating to PostgreSQL for production use
2. **Web Server**: Use Puma or Passenger for production deployment
3. **Environment Variables**: Set `DATABASE_URL` for custom database connection
4. **Logging**: Configure appropriate logging levels
5. **Monitoring**: Implement health checks and monitoring

### Running in Production

```bash
# Set environment
export RACK_ENV=production
export DATABASE_URL=sqlite://db/production.db

# Run migrations
bundle exec rake db:migrate

# Start server
bundle exec puma -C config/puma.rb
```

### Docker Deployment (Optional)

Create a `Dockerfile`:

```dockerfile
FROM ruby:3.3.6

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
RUN bundle exec rake db:migrate

EXPOSE 4567
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:4567"]
```

Build and run:
```bash
docker build -t ld-shacl-bridge .
docker run -p 4567:4567 ld-shacl-bridge
```

## Troubleshooting

### Common Issues

**Issue**: Database errors on startup
**Solution**: Run `bundle exec rake db:migrate`

**Issue**: Tests failing with database errors
**Solution**: Delete `db/test.db` and run tests again

**Issue**: Port already in use
**Solution**: Change port in `app.rb` or kill process using port 4567

### Debug Mode

Enable debug logging by setting environment variable:
```bash
export RACK_ENV=development
```

## Future Enhancements

Potential improvements for the application:

1. **SHACL Validation**: Add endpoint to validate JSON-LD against stored SHACL shapes
2. **Context Caching**: Cache frequently used JSON-LD contexts
3. **Advanced SHACL**: Generate more sophisticated SHACL constraints (ranges, patterns, etc.)
4. **API Authentication**: Add authentication and authorization
5. **Versioning**: Support versioning of frames and SHACL shapes
6. **Bulk Operations**: Support batch conversion and retrieval
7. **Export Formats**: Support multiple SHACL serialization formats (JSON-LD, RDF/XML)

## References

- [JSON-LD Specification](https://www.w3.org/TR/json-ld11/)
- [SHACL Specification](https://www.w3.org/TR/shacl/)
- [Sinatra Documentation](https://sinatrarb.com/)
- [RDF.rb Documentation](https://ruby-rdf.github.io/)
- [Sequel ORM](https://sequel.jeremyevans.net/)

---

**Version**: 1.0.0  
**Author**: Manus AI  
**Date**: December 11, 2024
