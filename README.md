# Decidim 0.31 Docker Build

Custom Docker image for [Decidim](https://decidim.org/) 0.31.0 with known bug fixes applied. Includes a multi-stage Dockerfile (Ruby 3.3, Node.js 20), PostgreSQL 15, Redis 7, and a Caddy reverse-proxy config with automatic HTTPS.

## Repository structure

```
.
├── build/
│   ├── Dockerfile        # Multi-stage build: builder + production image
│   ├── add_gems.rb       # Adds pg and sidekiq gems to the generated Gemfile
│   ├── database.yml      # Rails database config (reads from ENV)
│   └── entrypoint.sh     # Waits for DB, runs migrations, starts Puma
├── docker-compose.yml    # Orchestrates decidim, postgres, redis
├── Caddyfile             # Reverse proxy with security headers
├── .env.example          # Template for secrets
└── README.md
```

## Quick start

```bash
# 1. Clone
git clone https://github.com/robertsauer-ernst/decidim-docker.git
cd decidim-docker

# 2. Create .env with your secrets
cp .env.example .env
# Edit .env — set POSTGRES_PASSWORD and SECRET_KEY_BASE
# Generate a secret key with: docker run --rm ruby:3.3-slim ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"

# 3. Build and start
docker compose up -d --build

# 4. Create the first admin user (first run only)
docker exec -it decidim-app bundle exec rails decidim:system:create_admin
```

Decidim will be available at `http://localhost:3000`. Use the included `Caddyfile` with Caddy for TLS termination in production (adjust the domain name).

## Configuration

All runtime configuration is done via environment variables in `docker-compose.yml` / `.env`:

| Variable | Description |
|---|---|
| `POSTGRES_PASSWORD` | PostgreSQL password (used by both db and app) |
| `SECRET_KEY_BASE` | Rails secret key (64+ hex chars) |
| `DATABASE_HOST` | Database hostname (default: `db`) |
| `REDIS_URL` | Redis connection URL (default: `redis://redis:6379/1`) |

## Known bugs in Decidim 0.31

### 1. Broken color/theme customization

The admin panel's "Appearance" color settings (primary color, secondary color, etc.) have no effect. This is a known upstream bug in Decidim 0.31 where CSS custom properties are not correctly applied from the admin-configured values. Custom colors must be applied via a CSS override or a custom theme file mounted into the container.

### 2. SMTP STARTTLS issue

Decidim 0.31 has a bug where SMTP delivery with `STARTTLS` fails silently or raises connection errors on some mail servers. The `enable_starttls_auto` setting does not work correctly in certain configurations. Workarounds:

- Use port 465 with implicit TLS (`ssl: true`) instead of port 587 with STARTTLS
- Or set `enable_starttls: false` and `enable_starttls_auto: false` explicitly in the SMTP initializer, then rely on an external relay (e.g., local Postfix) that handles TLS itself

## Updating

To rebuild after changes:

```bash
docker compose down
docker compose up -d --build
```

## License

Decidim is licensed under the [GNU AGPL v3](https://github.com/decidim/decidim/blob/develop/LICENSE-AGPLv3.txt). This repository contains configuration and build files only.
