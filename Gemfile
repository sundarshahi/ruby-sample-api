# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.4.9"

# Web framework — minimal, no Rails overhead
gem "kamal"
gem 'rake'
gem "sinatra",        "~> 4.0"
gem "sinatra-contrib", "~> 4.0"  # namespace, json helpers
gem "puma",           "~> 6.4"   # Production app server

# Database
gem "sequel",         "~> 5.82"  # Lightweight ORM
gem "pg",             "~> 1.5"   # PostgreSQL adapter

# Utilities
gem "dotenv",         "~> 3.1"   # Env vars in dev
gem "oj",             "~> 3.16"  # Fast JSON serialiser
gem "rack-cors",      "~> 2.0"   # CORS headers

group :development, :test do
  gem "rspec",        "~> 3.13"
  gem "rack-test",    "~> 2.1"
  gem "rubocop",      "~> 1.65", require: false
  gem "rubocop-rspec","~> 3.0",  require: false
  gem "database_cleaner-sequel", "~> 2.0"
  gem "factory_bot",  "~> 6.4"
  gem "faker",        "~> 3.4"
  gem "simplecov",    "~> 0.22", require: false
end
