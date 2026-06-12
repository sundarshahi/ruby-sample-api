# frozen_string_literal: true

require "sinatra/base"
require "sinatra/json"
require "sinatra/namespace"
require "rack/cors"
require "oj"
require "sequel"
require "dotenv/load" if ENV["RACK_ENV"] == "development"

require_relative "config/database"
require_relative "config/app_config"
require_relative "models/post"
require_relative "controllers/health_controller"
require_relative "controllers/posts_controller"

Oj.default_options = { mode: :compat }

class App < Sinatra::Base
  register Sinatra::Namespace

  # ── Middleware ──────────────────────────────────────────────────────────────
  use Rack::Cors do
    allow do
      origins ENV.fetch("ALLOWED_ORIGINS", "*")
      resource "*", headers: :any, methods: %i[get post put patch delete options]
    end
  end

  configure do
    set :show_exceptions, false
    set :raise_errors,    false
    set :logging,         true
    set :dump_errors,     false
  end

  # ── Global error handlers ───────────────────────────────────────────────────
  error Sequel::ValidationFailed do |e|
    status 422
    json error: "Validation failed", details: e.errors
  end

  error Sequel::NoMatchingRow do
    status 404
    json error: "Record not found"
  end

  error Sinatra::NotFound do
    status 404
    json error: "Route not found"
  end

  error StandardError do |e|
    $stderr.puts "[ERROR] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    status 500
    json error: "Internal server error"
  end

  # ── Routes ──────────────────────────────────────────────────────────────────
  register HealthController
  register PostsController

  # ── Request logging middleware ──────────────────────────────────────────────
  before do
    @started_at = Time.now
    content_type :json
  end

  after do
    elapsed = ((Time.now - @started_at) * 1000).round(2)
    puts "[#{Time.now.utc.iso8601}] #{request.request_method} #{request.path_info} → #{response.status} (#{elapsed}ms)"
  end
end
