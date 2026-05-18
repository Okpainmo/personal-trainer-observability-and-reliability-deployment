# Personal Trainer Observability And Reliability Deployment

Production-style observability and reliability platform for a demo `trainer-api` service. The stack is provisioned as code and uses the LGTM stack: Loki, Grafana, Tempo, and Prometheus.

## What is included

- Prometheus metrics collection and alert evaluation.
- Loki log aggregation.
- Tempo distributed tracing.
- Grafana dashboards and datasources provisioned as code.
- Node Exporter for CPU, memory, disk, network, and load metrics.
- Blackbox Exporter for uptime, HTTP latency, and SSL probing.
- Alertmanager routing, inhibition, and structured Slack notifications.
- OpenTelemetry Collector for logs and traces.
- OpenTelemetry-instrumented FastAPI service.
- DORA exporter for deployment frequency, lead time, CFR, and MTTR.
- SLI, SLO, error-budget, runbook, and Game Day documentation.

## Architecture

See [docs/architecture.md](docs/architecture.md) for Mermaid diagrams covering:

- LGTM data flow.
- SLI to SLO to error-budget to alert pipeline.
- metric-to-log-to-trace drill-down.
- Docker Compose deployment topology.

## Prerequisites

- Docker and Docker Compose.
- Terraform 1.5 or newer.
- A Slack incoming webhook for `#DevOps-Alerts`.
- Optional: GitHub token with Actions read access for live DORA metrics.

## One-command deployment

Create a Terraform variables file:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Set the Slack webhook in `terraform/terraform.tfvars`:

```hcl
slack_webhook_url = "https://hooks.slack.com/services/..."
```

Bring up the full platform:

```bash
make up
```

The `make up` target runs:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply -auto-approve
```

Terraform creates the sensitive Slack webhook file and starts the Docker Compose stack.

## Service URLs

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093
- Trainer API: http://localhost:8080
- Loki: http://localhost:3100
- Tempo: http://localhost:3200

Default Grafana credentials are `admin` / `admin` unless changed through `.env`.

## Dashboards

All dashboards are provisioned from `observability/grafana/dashboards`.

- DORA Metrics: deployment frequency, classification, lead time, CFR, MTTR.
- SLO & Error Budget: SLI gauges, budget remaining, burn rate, compliance history.
- Node Exporter: CPU, memory, disk I/O, network I/O, load averages.
- Blackbox Exporter: uptime timeline, response time, SSL expiry, probe success rate.
- Unified Observability: request rate, latency, errors, Loki logs, Tempo traces.

The Loki datasource includes a derived field for `trace_id`, so logs from `trainer-api` can click through directly to Tempo.

## Reliability definitions

SLIs, SLO targets, rationale, and error-budget math are documented in [docs/sli-slo-error-budget.md](docs/sli-slo-error-budget.md).

Error budget policy is documented in [docs/error-budget-policy.md](docs/error-budget-policy.md).

## Alerting

Prometheus alert rules live in `observability/prometheus/rules`.

Alertmanager config lives in `observability/alertmanager`.

All alerts route to `#DevOps-Alerts` and include:

- alert name
- severity
- service and host/instance
- current value
- dashboard link
- runbook link
- firing or resolved status

Inhibition suppresses node-level noise when the matching instance is already unreachable.

## Runbooks

Runbooks live in `runbooks`.

Current runbooks cover:

- CPU saturation
- memory saturation
- disk saturation
- instance down
- SLO burn rate
- change failure rate
- MTTR too high

## DORA metrics

DORA details are in [docs/dora.md](docs/dora.md).

For live GitHub Actions data, set these environment variables before running the stack:

```bash
export GITHUB_REPOSITORY=owner/repository
export GITHUB_TOKEN=ghp_xxx
export DEPLOYMENT_WORKFLOW_NAME=deploy.yml
```

Without GitHub credentials, the exporter emits fallback data so the dashboard remains usable.

## Game Day

Game Day instructions are in [docs/gameday.md](docs/gameday.md).

Quick commands:

```bash
make gameday-latency
make gameday-errors
make gameday-cpu
```

## Team ownership model

Suggested split for a team task:

- Platform/IaC: Terraform and Docker Compose.
- Telemetry: Prometheus, Loki, Tempo, OpenTelemetry Collector.
- Reliability: SLIs, SLOs, error budgets, burn-rate alerts.
- Dashboards: Grafana provisioning and dashboard JSON.
- CI/CD observability: GitHub Actions and DORA exporter.
- Incident response: Alertmanager, Slack templates, runbooks, Game Day validation.

## Validation

Run static validation:

```bash
make validate
```

Inspect running services:

```bash
make ps
```
