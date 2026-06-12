# syntax=docker/dockerfile:1.7
# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: dependencies  — install gems (layer cached unless Gemfile changes)
# Stage 2: runtime       — minimal image, non-root user, no build tools
# ─────────────────────────────────────────────────────────────────────────────

ARG RUBY_VERSION=3.3.0

# ── Stage 1: gems ─────────────────────────────────────────────────────────────
FROM ruby:${RUBY_VERSION}-slim AS gems

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install --jobs 4 --retry 3

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM ruby:${RUBY_VERSION}-slim AS runtime

ARG BUILD_DATE
ARG GIT_SHA=unknown
ARG APP_VERSION=unknown

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${APP_VERSION}"

# Runtime-only system deps
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libpq5 \
      curl \
    && rm -rf /var/lib/apt/lists/* && \
    useradd -r -u 1000 -m -s /bin/bash appuser

WORKDIR /app

# Copy gems from build stage
COPY --from=gems /usr/local/bundle /usr/local/bundle

# Copy application source
COPY --chown=appuser:appuser . .

# Ensure tmp dirs exist
RUN mkdir -p tmp/pids log && chown -R appuser:appuser tmp log

USER appuser

# Environment defaults (override at runtime)
ENV RACK_ENV=production \
    PORT=3000 \
    WEB_CONCURRENCY=2 \
    RAILS_MAX_THREADS=5 \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test"

EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:3000/health || exit 1

# Run DB migrations then start Puma
CMD ["sh", "-c", "bundle exec rake db:migrate && bundle exec puma -C config/puma.rb"]
