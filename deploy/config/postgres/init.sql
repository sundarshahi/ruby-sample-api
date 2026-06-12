-- config/postgres/init.sql
-- Runs once when the container first starts (PostgreSQL initdb hook)

-- Extensions useful for production apps
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- Enables fast ILIKE / full-text search

-- Enforce UTC
SET timezone = 'UTC';
