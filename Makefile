SHELL := /bin/bash

.PHONY: up down restart validate logs status health gameday-latency gameday-errors gameday-cpu

up:
	terraform -chdir=terraform init
	terraform -chdir=terraform apply -auto-approve

down:
	terraform -chdir=terraform destroy -auto-approve

restart:
	sudo systemctl restart prometheus alertmanager loki tempo otel-collector node-exporter blackbox-exporter trainer-api dora-exporter grafana-server

validate:
	terraform -chdir=terraform fmt -check
	terraform -chdir=terraform validate
	python3 -m json.tool observability/grafana/dashboards/dora.json >/dev/null
	python3 -m json.tool observability/grafana/dashboards/unified-observability.json >/dev/null
	python3 -m py_compile services/trainer-api/app.py services/dora-exporter/exporter.py

logs:
	journalctl -fu prometheus -u alertmanager -u loki -u tempo -u otel-collector -u trainer-api -u dora-exporter -u grafana-server

status:
	systemctl --no-pager --full status prometheus alertmanager loki tempo otel-collector node-exporter blackbox-exporter trainer-api dora-exporter grafana-server

health:
	curl -fsS http://localhost:8080/health
	curl -fsS http://localhost:9090/-/healthy
	curl -fsS http://localhost:3100/ready
	curl -fsS http://localhost:3200/ready

gameday-latency:
	curl -fsS "http://localhost:8080/workout?delay_ms=1200"

gameday-errors:
	curl -fsS "http://localhost:8080/workout?fail=true" || true

gameday-cpu:
	stress-ng --cpu 2 --timeout 8m --metrics-brief
