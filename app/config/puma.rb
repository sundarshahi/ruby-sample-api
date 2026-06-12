# config/puma.rb — Production Puma configuration
# Change 'import' to 'require'
require 'fileutils'
FileUtils.mkdir_p("tmp/pids")

workers     ENV.fetch("WEB_CONCURRENCY", 2).to_i
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
threads     threads_count, threads_count

port        ENV.fetch("PORT", 3000)
environment ENV.fetch("RACK_ENV", "development")

# PID file for process management
pidfile     ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Preload for faster worker spawns (copy-on-write friendly)
preload_app!

on_worker_boot do
  # Reconnect DB after fork
  DB.disconnect if defined?(DB)
end

# Graceful shutdown
on_restart do
  DB.disconnect if defined?(DB)
end
