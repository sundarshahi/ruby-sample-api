# frozen_string_literal: true

# config/app_config.rb

module AppConfig
  APP_NAME    = ENV.fetch("APP_NAME",    "ruby-api")
  APP_VERSION = ENV.fetch("APP_VERSION", "unknown")
  RACK_ENV    = ENV.fetch("RACK_ENV",    "development")
  STARTED_AT  = Time.now.utc.freeze

  def self.production?  = RACK_ENV == "production"
  def self.development? = RACK_ENV == "development"
  def self.test?        = RACK_ENV == "test"
end
