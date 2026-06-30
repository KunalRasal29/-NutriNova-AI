DOCKER_COMPOSE ?= docker compose

.PHONY: up down backend-shell migrate ensure-local-storage test lint createsuperuser

up:
	$(DOCKER_COMPOSE) up --build

down:
	$(DOCKER_COMPOSE) down

backend-shell:
	$(DOCKER_COMPOSE) exec backend python manage.py shell

migrate:
	$(DOCKER_COMPOSE) run --rm backend python manage.py migrate

ensure-local-storage:
	$(DOCKER_COMPOSE) run --rm backend python manage.py ensure_local_storage

test:
	$(DOCKER_COMPOSE) run --rm backend pytest

lint:
	$(DOCKER_COMPOSE) run --rm backend sh -c "ruff check . && black --check . && isort --check-only ."

createsuperuser:
	$(DOCKER_COMPOSE) run --rm backend python manage.py createsuperuser
