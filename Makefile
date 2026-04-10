.PHONY: help deps-up deps-down vault-setup db-setup test_all

DC            = docker compose
DATABASE_PASS = abc123
DATABASE_PORT = 3307
REDIS_URL     = redis://localhost:6380/1
RABBITMQ_HOST = localhost
RABBITMQ_PORT = 5673
VAULT_TOKEN   = changeme
VAULT_ADDR    = http://localhost:8200

TEST_ENV = DATABASE_PASS=$(DATABASE_PASS) \
           DATABASE_PORT=$(DATABASE_PORT) \
           BARONG_REDIS_URL=$(REDIS_URL) \
           BARONG_EVENT_API_RABBITMQ_HOST=$(RABBITMQ_HOST) \
           BARONG_EVENT_API_RABBITMQ_PORT=$(RABBITMQ_PORT) \
           BARONG_VAULT_TOKEN=$(VAULT_TOKEN) \
           BARONG_VAULT_ADDRESS=$(VAULT_ADDR)

help:
	@echo "Available targets:"
	@echo "  deps-up      Start test dependencies (MySQL, RabbitMQ, Redis, Vault)"
	@echo "  deps-down    Stop and remove test dependency containers"
	@echo "  vault-setup  Initialize Vault secrets engines (run once after deps-up)"
	@echo "  db-setup     Create and migrate the test database (run once after deps-up)"
	@echo "  test_all     Start dependencies and run the full test suite"

deps-up:
	$(DC) up -d --wait

deps-down:
	$(DC) down --volumes

vault-setup: deps-up
	VAULT_TOKEN=$(VAULT_TOKEN) VAULT_ADDR=$(VAULT_ADDR) \
	  $(DC) exec vault sh -c ' \
	    vault secrets disable secret && \
	    vault secrets enable -path=secret -version=1 kv && \
	    vault secrets enable totp && \
	    vault secrets enable transit'

db-setup: deps-up
	$(TEST_ENV) bundle exec rake db:create db:migrate RAILS_ENV=test

test_all: deps-up vault-setup db-setup
	$(TEST_ENV) bundle exec rspec
