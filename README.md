# Ruby API — Kamal on AWS EC2

Minimal, production-ready Ruby (Sinatra) API deployed to a single AWS EC2
instance via Kamal 2, with automated CI/CD in GitHub Actions.

---

## What's included

| Layer | Technology |
|---|---|
| App | Ruby 3.3 · Sinatra 4 · Puma 6 |
| DB | PostgreSQL 16 (Docker sidecar on same EC2) |
| Proxy | Traefik (managed by Kamal) · Auto TLS via Let's Encrypt |
| Deploy | Kamal 2 — zero-downtime rolling restarts over SSH |
| Container registry | GitHub Container Registry (GHCR) — free |
| Infra IaC | Terraform — 1× t3.micro EC2, Elastic IP, VPC, Security Group |
| CI | GitHub Actions — lint + test + security scan + docker build check |
| CD | GitHub Actions — build & push image → Kamal deploy on push to main |

**Monthly cost estimate: ~$8.50** (t3.micro on-demand, us-east-1).
Upgrade to t3.small (~$15/mo) if you need more memory.

---

## Architecture

```
                     GitHub Actions
                     ┌──────────────────────────────────────┐
  git push ──────►  │  CI: lint → test → security → build  │
                     │  CD: docker build → GHCR push →       │
                     │      kamal deploy (SSH)               │
                     └────────────────┬─────────────────────┘
                                      │ SSH + Docker
                                      ▼
                         ┌─── AWS EC2 t3.micro ────────────┐
                         │                                  │
                         │  Elastic IP ──► Traefik :80/443  │
                         │  (Let's Encrypt TLS auto-renew)  │
                         │           │                      │
                         │           ▼                      │
                         │  Docker: ruby-api :3000          │
                         │           │                      │
                         │           ▼                      │
                         │  Docker: postgres :5432          │
                         │  (loopback only, not public)     │
                         │                                  │
                         │  EBS 20GB gp3 (encrypted)       │
                         └──────────────────────────────────┘
```

Kamal's Traefik proxy handles:
- HTTP → HTTPS redirect
- TLS certificate from Let's Encrypt (auto-renewed)
- Health-checked rolling restarts (new container must pass `/health/ready` before traffic switches)

---

## Quick Start

### 1. Provision EC2 with Terraform

```bash
# Bootstrap S3 for Terraform state (once)
aws s3 mb s3://tfstate-ruby-api --region us-east-1

make infra-init
make infra-plan    # review
make infra-apply

# Note the Elastic IP from output:
make infra-output
# server_ip = "1.2.3.4"
```

### 2. Point DNS at the Elastic IP

Create an `A` record: `api.yourdomain.com → 1.2.3.4`

### 3. Set GitHub Secrets & Variables

Go to **Settings → Secrets and variables → Actions**:

| Name | Type | Value |
|---|---|---|
| `DEPLOY_SSH_PRIVATE_KEY` | Secret | Private key matching the public key used in Terraform |
| `DEPLOY_HOST` | Secret | Elastic IP from Terraform output |
| `DATABASE_URL` | Secret | `postgres://appuser:password@127.0.0.1/ruby_api_production` |
| `SECRET_KEY_BASE` | Secret | `openssl rand -hex 64` |
| `POSTGRES_USER` | Secret | `appuser` |
| `POSTGRES_PASSWORD` | Secret | A strong password |
| `DEPLOY_DOMAIN` | Variable | `api.yourdomain.com` |
| `ALLOWED_ORIGINS` | Variable | `https://yourdomain.com` |

### 4. First-time server setup (run once)

```bash
# Installs Docker, sets up Traefik, pulls DB — takes ~2 minutes
cd deploy && kamal setup
```

### 5. Deploy

```bash
# Manual first deploy
cd deploy && kamal deploy

# After this, every push to main auto-deploys via GitHub Actions
```

---

## API Endpoints

```
GET  /health            — liveness probe
GET  /health/ready      — readiness probe (includes DB check)

GET  /api/v1/posts              — list posts (paginated, ?page=1&q=search)
GET  /api/v1/posts/:id          — get post
POST /api/v1/posts              — create post
PATCH /api/v1/posts/:id         — update post
DELETE /api/v1/posts/:id        — delete post
```

### Example

```bash
BASE="https://api.yourdomain.com"

# Create
curl -X POST $BASE/api/v1/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"Hello","body":"World","status":"published"}'

# List
curl "$BASE/api/v1/posts?page=1"
```

---

## CI/CD Pipeline

```
push to any branch
  └── CI workflow
        ├── RuboCop lint
        ├── RSpec tests (with Postgres service)
        ├── bundle-audit (CVE check)
        ├── Brakeman (static security analysis)
        └── Docker build check + Trivy scan

push to main (after CI passes)
  └── Deploy workflow
        ├── Build Docker image
        ├── Push to GHCR (ghcr.io/org/repo/ruby-api)
        ├── kamal deploy --version=<sha>
        │     ├── SSH to EC2
        │     ├── docker pull new image
        │     ├── boot new container
        │     ├── wait for /health/ready → 200
        │     └── switch Traefik → new container (zero-downtime)
        └── Smoke test (curl /health/ready)
```

---

## Kamal Operations

```bash
# View live logs
make deploy-logs

# Open shell on running container
make deploy-exec

# Roll back to previous version
cd deploy && kamal rollback

# Restart app without redeploy
cd deploy && kamal app restart

# Run a one-off command
cd deploy && kamal app exec "bundle exec rake db:migrate"

# View Traefik dashboard (port-forward)
cd deploy && kamal traefik logs
```

---

## Local Development

```bash
make setup        # install gems, copy .env.example → .env
# edit app/.env with your local DATABASE_URL

make dev          # start server at http://localhost:3000
make test         # run RSpec
make lint         # RuboCop
make security     # bundle-audit + brakeman
```

---

## Security posture

- **IMDSv2 enforced** — EC2 metadata not accessible without session token
- **Port 22 restricted** — set `allowed_ssh_cidr` to your IP in `terraform.tfvars`
- **Port 5432 not exposed** — Postgres binds to `127.0.0.1` only
- **EBS volume encrypted** — data at rest encrypted
- **Non-root Docker user** — app runs as `appuser` (uid 1000)
- **GHCR private** — container images private to your org
- **Secrets in GitHub** — no secrets in code or Dockerfile
- **Trivy on every build** — image scanned for CVEs
- **bundle-audit on every CI run** — gem CVEs caught early
- **Brakeman static analysis** — security-focused code scan

---

## Upgrading the DB to RDS

When you outgrow the Docker-sidecar Postgres:

1. Create an RDS instance (free-tier `db.t3.micro` is fine to start)
2. Update `DATABASE_URL` GitHub secret to the RDS endpoint
3. Remove the `accessories.db` block from `deploy/deploy.yml`
4. Push to main — Kamal redeploys, app connects to RDS

Zero code changes needed.
