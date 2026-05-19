# Reusable Bare-Metal Observability And Reliability Platform

This repository deploys an adaptable production-style observability and reliability platform with a a built-in smoke-test `test-api` service - all on bare metal Linux using Terraform and systemd. It does not use Docker.

## Stack

- Prometheus for metrics and alert rule evaluation.
- Loki for logs.
- Tempo for distributed traces.
- Grafana for dashboards, Explore, and metric/log/trace correlation.
- Alertmanager for Slack alert routing.
- Node Exporter for host CPU, memory, disk, network, and load metrics.
- Blackbox Exporter for uptime, HTTP latency, and SSL expiry probes.
- OpenTelemetry Collector for traces and journald log shipping.
- `test-api`, an OpenTelemetry-instrumented FastAPI service.
- DORA Exporter for deployment frequency, lead time, CFR, and MTTR.

`test-api` is not the product being monitored. It is an internal demo workload used to verify metrics, logs, traces, SLOs, dashboards, and alerts. In production, replace or extend its targets with the external services you want this reusable observability platform to monitor.

## Architecture

See [docs/architecture.md](docs/architecture.md).

Short flow:

```text
test-api metrics -> Prometheus -> Alertmanager -> Slack
test-api traces -> OpenTelemetry Collector -> Tempo
systemd journals -> OpenTelemetry Collector -> Loki
Grafana -> Prometheus + Loki + Tempo
```

## Prerequisites

- Linux host with systemd.
- Terraform 1.5 or newer.
- `sudo` privileges.
- Internet access for first-time binary installation.
- Slack incoming webhook for `#detrudr-alerts-demo`.

The install script supports Debian/Ubuntu with `apt-get` and RHEL-like systems with `yum`.

## One-command deployment

Create local Terraform variables:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
slack_webhook_url = "https://hooks.slack.com/services/..."
grafana_admin_user = "admin"
grafana_admin_password = "change-me"
github_repository = "owner/repository"
github_token = ""
deployment_workflow_name = "deploy.yml"
install_binaries = true
deploy_test_api = false
test_api_port = 8081
monitored_service_name = "personal-trainer-be"
monitored_service_metrics_target = "127.0.0.1:8080"
monitored_service_health_url = "http://127.0.0.1:8080/api/v1/health"
monitored_service_systemd_unit = "personal-trainer-be.service"
collect_local_monitored_service_logs = false
```

For a monitored service running on another server, set `monitored_service_metrics_target`
and `monitored_service_health_url` to the BE server address reachable from the
observability server. Keep `collect_local_monitored_service_logs = false`; send
BE logs from an app-host collector agent instead. See
[remote service integration](docs/remote-service-integration.md).

Deploy everything:

```bash
make up
```

Equivalent:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply -auto-approve
```

## What Terraform provisions

Terraform renders secrets, Grafana config, and systemd units into `terraform/.generated`, then calls the bare-metal provisioning scripts.

It installs or configures:

- `/usr/local/bin/prometheus`
- `/usr/local/bin/alertmanager`
- `/usr/local/bin/loki`
- `/usr/local/bin/tempo`
- `/usr/local/bin/otelcol-contrib`
- `/usr/local/bin/node_exporter`
- `/usr/local/bin/blackbox_exporter`
- Grafana server
- Python virtualenvs for `test-api` and `dora-exporter`
- systemd units for every component

Config root:

```text
/etc/observability-platform
```

Data root:

```text
/var/lib/observability-platform
```

App root:

```text
/opt/observability-platform
```

## Service URLs

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093
- Test API: http://localhost:8081 when `deploy_test_api = true`
- Loki API: http://localhost:3100
- Tempo API: http://localhost:3200
- Node Exporter: http://localhost:9100
- Blackbox Exporter: http://localhost:9115
- DORA Exporter: http://localhost:9108

Loki and Tempo are API backends. Their root browser URL may return `404`; use Grafana Explore.

## Useful commands

```bash
make up
make status
make logs
make health
make restart
make down
```

Inspect one service:

```bash
systemctl status test-api --no-pager
journalctl -u test-api -f
```

Generate telemetry:

```bash
curl http://localhost:8081/workout
curl "http://localhost:8081/workout?delay_ms=1200"
curl "http://localhost:8081/workout?fail=true"
```

## Dashboards

All dashboards are provisioned from `observability/grafana/dashboards`.

- DORA Metrics: deployment frequency, lead time, CFR, MTTR, classification.
- SLO & Error Budget: SLI gauges, budget remaining, burn rate, compliance history.
- Node Exporter: CPU, memory, disk I/O, network I/O, load averages.
- Blackbox Exporter: uptime, response time, SSL expiry, probe success rate.
- Unified Observability: request rate, error rate, latency, Loki logs, Tempo traces.

The Loki datasource has a derived field for `trace_id`, so logs can click through to Tempo traces.

## Alerting

Prometheus alert rules live in `observability/prometheus/rules`.

Alertmanager routes all alerts to:

```text
#detrudr-alerts-demo
```

Alerts include severity, affected service/host, current value, Grafana dashboard link, runbook link, and firing/resolved status.

## Reliability documentation

- [SLIs, SLOs, and error budgets](docs/sli-slo-error-budget.md)
- [Error budget policy](docs/error-budget-policy.md)
- [DORA metrics](docs/dora.md)
- [Game Day](docs/gameday.md)
- [Toil](docs/toil.md)
- [Runbooks](runbooks)

## Secret safety

Do not commit:

- `terraform/terraform.tfvars`
- `terraform/.generated/`
- `terraform/*.tfstate`
- `.terraform/`

These are ignored by `.gitignore`.
