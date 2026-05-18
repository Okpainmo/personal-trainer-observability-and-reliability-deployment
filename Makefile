SHELL := /bin/bash

.PHONY: up down restart validate logs ps gameday-latency gameday-errors gameday-cpu

up:
	terraform -chdir=terraform init
	terraform -chdir=terraform apply -auto-approve

down:
	docker compose -f docker-compose.yml down

restart:
	docker compose -f docker-compose.yml restart

validate:
	terraform -chdir=terraform fmt -check
	terraform -chdir=terraform validate
	docker compose -f docker-compose.yml config >/dev/null

logs:
	docker compose -f docker-compose.yml logs -f --tail=100

ps:
	docker compose -f docker-compose.yml ps

gameday-latency:
	curl -fsS "http://localhost:8080/workout?delay_ms=1200"

gameday-errors:
	curl -fsS "http://localhost:8080/workout?fail=true" || true

gameday-cpu:
	docker compose -f docker-compose.yml run --rm stress-ng --cpu 2 --timeout 8m --metrics-brief
