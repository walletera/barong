# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Barong is a **JWT-based authentication microservice** that provides user registration, RBAC, KYC verification, 2FA, API key management, and event-driven email. It integrates with Vault (encryption), RabbitMQ (events), Redis (sessions), and Sidekiq (background jobs).

## Commands

### Setup
```bash
bundle install
./bin/init_config        # generates config files from ERB templates
bundle exec rake db:create db:migrate
```

### Running Tests

Tests require MySQL, RabbitMQ, and Redis. Start them from `local-testing/`:

```bash
docker compose -f ../local-testing/mysql/compose.yml up -d
docker compose -f ../local-testing/rabbitmq/compose.yaml up -d
docker compose -f ../local-testing/redis/compose.yml up -d
```

The MySQL root password is `abc123` — pass it via env var:

```bash
DATABASE_PASS=abc123 bundle exec rake db:create db:migrate RAILS_ENV=test   # first time only
DATABASE_PASS=abc123 bundle exec rspec                                       # all tests
DATABASE_PASS=abc123 bundle exec rspec spec/path/to/file_spec.rb             # single file
DATABASE_PASS=abc123 bundle exec rspec spec/path/to/file_spec.rb:42          # single test at line
```

CI runs against MySQL 5.7, MariaDB 10.3, MySQL 8.0, and PostgreSQL 13.0.

### Development
```bash
bundle exec rails server
bundle exec sidekiq                                  # background jobs
```

## Architecture

### API Layer (Grape, not Rails controllers)

All endpoints are Grape APIs mounted at `/api`. Rails controllers are only used for the special auth endpoint.

```
app/api/v2/
├── identity/     # public: registration, login, password, sessions
├── public/       # public info, configs
├── resource/     # authenticated user endpoints (profile, phone, docs, API keys)
├── management/   # inter-service API (signed JWT, not user sessions)
└── admin/        # admin panel endpoints (requires admin role)
```

The auth flow: `GET /api/v2/auth/*path` → `AuthorizeController` validates session/JWT and returns user info as headers for upstream services.

### Key Models

- `User` — core entity; verification levels (0–3) set via `Label` records
- `Label` — categorize users (e.g., `email: verified`, `phone: verified`, `document: verified`); drives verification level
- `Permission` — RBAC via CanCanCan; defines which roles can access which Grape routes
- `APIKey` — JWT-signed API tokens for programmatic access
- `Profile` / `Phone` / `Document` — KYC data tied to users
- `Activity` — audit log for all significant user actions
- `ServiceAccount` — OAuth service accounts for inter-service auth

### Configuration System (`lib/barong/app.rb`)

All runtime config goes through `Barong::App.set(key, default, options)`. Values are read from `BARONG_*` env vars. This is the source of truth for feature flags and external service config (Vault, Twilio, captcha, etc.).

### Encryption

Sensitive model fields are encrypted via `vault-rails`. Vault must be running and accessible. In tests, Vault is typically mocked.

### Events

Models with `acts_as_eventable` publish domain events (e.g., `user.created`, `label.updated`) to RabbitMQ. The `EventMailer` service consumes these to send transactional emails. Event config is in `config/initializers/event_api.rb`.

### Testing Patterns

- FactoryBot factories in `spec/factories/`
- Database cleaner uses transactions by default, truncation for JS tests
- `allow_any_instance_of(Barong::Authorize)` is common for auth bypass in specs
- CSRF protection is disabled in the test environment
- Use `spec/support/` for shared contexts and helpers
