# spec/spec_helper.rb
require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

ENV["RACK_ENV"]     = "test"
ENV["SKIP_DB_CHECK"] = "1"

require "rack/test"
require "factory_bot"
require "database_cleaner/sequel"
require_relative "../app"

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
    DatabaseCleaner[:sequel].strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner[:sequel].cleaning { example.run }
  end

  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
end

def app = App.new
