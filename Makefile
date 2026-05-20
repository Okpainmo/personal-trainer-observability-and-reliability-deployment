SHELL := /bin/bash

.PHONY: up down restart validate validate-static logs status health gameday-latency gameday-errors gameday-cpu

up:
	terraform -chdir=terraform init
	terraform -chdir=terraform apply -auto-approve

down:
	terraform -chdir=terraform destroy -auto-approve

restart:
	sudo systemctl restart prometheus alertmanager loki tempo otel-collector node-exporter blackbox-exporter test-api dora-exporter grafana-server

validate-static:
	terraform -chdir=terraform fmt -check
	python3 -m json.tool observability/grafana/dashboards/dora.json >/dev/null
	python3 -m json.tool observability/grafana/dashboards/unified-observability.json >/dev/null
	python3 -m json.tool observability/grafana/dashboards/node-exporter.json >/dev/null
	python3 -m json.tool observability/grafana/dashboards/blackbox.json >/dev/null
	python3 -m json.tool observability/grafana/dashboards/slo-error-budget.json >/dev/null
	python3 -m json.tool services/dora-exporter/incidents.example.json >/dev/null
	python3 -c 'import ast,pathlib; [ast.parse(pathlib.Path(p).read_text()) for p in ["services/test-api/app.py","services/dora-exporter/exporter.py"]]'

validate: validate-static
	terraform -chdir=terraform validate

logs:
	journalctl -fu prometheus -u alertmanager -u loki -u tempo -u otel-collector -u test-api -u dora-exporter -u grafana-server

status:
	systemctl --no-pager --full status prometheus alertmanager loki tempo otel-collector node-exporter blackbox-exporter test-api dora-exporter grafana-server

health:
	curl -fsS http://localhost:8080/health
	curl -fsS http://localhost:9090/-/healthy
	curl -fsS http://localhost:3100/ready
	curl -fsS http://localhost:3200/ready

gameday-latency:
	curl -fsS "http://localhost:8081/workout?delay_ms=1200"

gameday-errors:
	curl -fsS "http://localhost:8081/workout?fail=true" || true

gameday-cpu:
	stress-ng --cpu 2 --timeout 8m --metrics-brief
