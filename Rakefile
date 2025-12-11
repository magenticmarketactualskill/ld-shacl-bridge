require 'sequel'

namespace :db do
  desc 'Run database migrations'
  task :migrate do
    Sequel.extension :migration
    db = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/development.db')
    Sequel::Migrator.run(db, 'db/migrations')
    puts 'Migrations completed successfully'
  end

  desc 'Reset database (drop and recreate)'
  task :reset do
    db_file = 'db/development.db'
    File.delete(db_file) if File.exist?(db_file)
    puts 'Database reset'
    Rake::Task['db:migrate'].invoke
  end
end

desc 'Run RSpec tests'
task :spec do
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
end

task default: :spec
