# frozen_string_literal: true

# controllers/health_controller.rb

module HealthController
  def self.registered(app)
    app.get "/health" do
      json status: "ok",
           env:     AppConfig::RACK_ENV,
           version: AppConfig::APP_VERSION
    end

    # Readiness: includes DB check (used by Kamal / ALB health checks)
    app.get "/health/ready" do
      begin
        DB.test_connection
        uptime = (Time.now.utc - AppConfig::STARTED_AT).round

        json status:   "ready",
             database: "connected",
             uptime_s: uptime
      rescue Sequel::DatabaseConnectionError => e
        status 503
        json status: "not_ready", database: "disconnected", error: e.message
      end
    end
  end
end
