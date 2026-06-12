###############################################################################
# Makefile — Developer shortcuts
###############################################################################

.PHONY: help setup dev test lint security docker-build deploy-setup infra-init infra-plan infra-apply

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── App ───────────────────────────────────────────────────────────────────────

setup: ## Install gems and set up local dev DB
	cd app && bundle install
	cp -n app/.env.example app/.env || true
	@echo "✅ Edit app/.env with your local settings"

dev: ## Start local dev server (requires Postgres running)
	cd app && bundle exec rake db:migrate && bundle exec puma -C config/puma.rb

test: ## Run RSpec tests
	cd app && RACK_ENV=test bundle exec rake db:migrate && bundle exec rspec spec/ --format documentation

lint: ## Run RuboCop
	cd app && bundle exec rubocop

security: ## Run bundle-audit + brakeman
	cd app && bundle-audit check --update
	cd app && brakeman --no-pager

# ── Docker ────────────────────────────────────────────────────────────────────

docker-build: ## Build Docker image locally
	docker build -f app/Dockerfile \
		--build-arg GIT_SHA=$(shell git rev-parse --short HEAD) \
		--build-arg APP_VERSION=local \
		-t ruby-api:local app/

docker-run: docker-build ## Run app locally in Docker (needs .env)
	docker run --rm -p 3000:3000 \
		--env-file app/.env \
		ruby-api:local

# ── Kamal ─────────────────────────────────────────────────────────────────────

deploy-setup: ## First-time server setup (run once after `make infra-apply`)
	cd deploy && kamal setup

deploy: ## Deploy to production
	cd deploy && kamal deploy

deploy-logs: ## Tail production logs
	cd deploy && kamal app logs -f

deploy-exec: ## Open a shell on the server
	cd deploy && kamal app exec -i bash

# ── Terraform ─────────────────────────────────────────────────────────────────

infra-init: ## Terraform init
	cd infra/terraform && terraform init

infra-plan: ## Terraform plan
	cd infra/terraform && terraform plan -var="ssh_public_key=$$(cat ~/.ssh/id_rsa.pub)"

infra-apply: ## Terraform apply — creates EC2
	cd infra/terraform && terraform apply -var="ssh_public_key=$$(cat ~/.ssh/id_rsa.pub)"

infra-output: ## Show Terraform outputs
	cd infra/terraform && terraform output
