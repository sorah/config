# frozen_string_literal: true

# Schema is managed by psqldef from db/schema/*.sql; Rails' migration and schema tasks do not apply.
# db:create and db:drop stay as Rails defines them.
Rake::Task.tasks.each do |task|
  case task.name
  when /\Adb:schema:/, /\Adb:migrate(:|\z)/, 'db:rollback', 'db:setup', 'db:prepare', /\Adb:test:/
    task.clear
  end
end

module DatabaseTasks
  def self.database_config
    database = ::Rails.application.config_for(:database)
    if ENV.key?('DATABASE_URL')
      database = database.merge(
        ActiveRecord::DatabaseConfigurations::ConnectionUrlResolver.new(ENV['DATABASE_URL']).to_hash,
      )
    end
    database
  end

  # In development, dev and test schemas are maintained together.
  def self.target_configs
    if ENV['DATABASE_URL'] || ENV['SKIP_TEST_DATABASE'] || !Rails.env.development?
      [database_config]
    else
      [database_config, Rails.application.config_for(:database, env: 'test')]
    end
  end

  def self.pg_env(config)
    {
      'PGHOST' => config[:host]&.to_s,
      'PGPORT' => config[:port]&.to_s,
      'PGUSER' => config[:username]&.to_s,
      'PGPASSWORD' => config[:password]&.to_s,
      'PGDATABASE' => config.fetch(:database).to_s,
      'PGSSLMODE' => config[:sslmode]&.to_s,
      'PGSSLROOTCERT' => config[:sslrootcert]&.to_s,
    }
  end

  def self.run(cmd, env:)
    p cmd
    system(env, *cmd, exception: true)
  end

  def self.psqldef(args, config: database_config)
    Tempfile.open('schema.sql') do |f|
      Dir[Rails.root.join('db', 'schema', '*.sql')].sort.each do |path|
        f.puts File.read(path)
      end
      f.flush
      env = pg_env(config)
      run(
        [
          'psqldef',
          # psqldef takes the password from PGPASSWORD; flags for the rest keep the command readable in logs.
          *(env['PGHOST'] ? ['--host', env['PGHOST']] : []),
          *(env['PGPORT'] ? ['--port', env['PGPORT']] : []),
          *(env['PGUSER'] ? ['--user', env['PGUSER']] : []),
          '--config-inline', JSON.generate({target_schema: config.fetch(:schema_search_path, 'public')}),
          # Grants only widen; narrowing one needs a manual REVOKE via BEFORE_APPLY_SQL.
          '--config-inline', JSON.generate({manage: {privilege: [{target: 'app_admin'}, {target: 'app_user'}]}}),
          '--file', f.path,
          *args,
          env.fetch('PGDATABASE'),
        ],
        env:,
      )
    end
  end
end

namespace :db do
  desc "Apply db/schema/*.sql with psqldef (BEFORE_APPLY_SQL runs first, ENABLE_DROP=1 allows drops)"
  task migrate: :load_config do
    DatabaseTasks.target_configs.each do |config|
      if ENV['BEFORE_APPLY_SQL'].to_s != ''
        puts "Running before-apply SQL: #{ENV["BEFORE_APPLY_SQL"]}"
        DatabaseTasks.run(
          ['psql', '-v', 'ON_ERROR_STOP=1', '-c', ENV.fetch('BEFORE_APPLY_SQL')],
          env: DatabaseTasks.pg_env(config),
        )
      end
      args = []
      args << '--enable-drop' if ENV['ENABLE_DROP'] == '1'
      DatabaseTasks.psqldef(args, config:)
    end
  end

  desc "Show the psqldef plan without applying it"
  task 'migrate:status' => :load_config do
    DatabaseTasks.psqldef(['--dry-run'])
  end

  desc "Create the database (if needed) and apply the schema"
  task setup: ['db:create', 'db:migrate', 'db:seed']

  desc "Create the database (if needed) and apply the schema, without seeding"
  task prepare: ['db:create', 'db:migrate']
end
