ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = 'sqlite://db/test.db'

require 'rspec'
require 'rack/test'
require 'sequel'

# Set up test database before loading app
test_db = Sequel.connect(ENV['DATABASE_URL'])
# Drop tables in correct order to avoid foreign key constraints
if test_db.tables.any?
  test_db.drop_table(:frames_shacls) if test_db.tables.include?(:frames_shacls)
  test_db.drop_table(:frames) if test_db.tables.include?(:frames)
  test_db.drop_table(:shacls) if test_db.tables.include?(:shacls)
end
Sequel.extension :migration
Sequel::Migrator.run(test_db, 'db/migrations')
test_db.disconnect

require_relative '../app'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  # Define the app for Rack::Test
  def app
    Sinatra::Application
  end

  # Clean database before each test
  config.before(:each) do
    DB[:frames_shacls].delete
    DB[:frames].delete
    DB[:shacls].delete
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
