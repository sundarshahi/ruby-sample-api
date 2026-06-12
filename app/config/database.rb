# frozen_string_literal: true

# config/database.rb — Sequel connection with pool, migrations support

DATABASE_URL = ENV.fetch("DATABASE_URL") do
  env = ENV.fetch("RACK_ENV", "development")
  case env
  when "test"        then "postgres://postgres:postgres@localhost/app_test"
  when "production"  then raise "DATABASE_URL must be set in production"
  else                    "postgres://postgres:postgres@localhost/app_development"
  end
end

DB = Sequel.connect(
  DATABASE_URL,
  max_connections:     ENV.fetch("DB_POOL",     "5").to_i,
  pool_timeout:        ENV.fetch("DB_TIMEOUT", "30").to_i,
  logger:              ENV["DB_LOGGING"] ? Logger.new($stdout) : nil,
  sql_log_normalizer:  ->(sql) { sql.gsub(/\s+/, " ").strip }
)

# Enable extensions
DB.extension :pagination
DB.extension :connection_validator

# Verify connection on boot (fast fail instead of first-request fail)
DB.test_connection unless ENV["SKIP_DB_CHECK"]
