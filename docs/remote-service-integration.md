# Remote Service Integration

Use this when the monitored application runs on a different server from the
observability stack.

Remote mode keeps the central observability host responsible for dashboards,
alerts, storage, and probes. The application host remains responsible for
exposing metrics and pushing logs/traces when those signals are available.

## Signal Ownership

| Signal | Direction | Requirement |
| --- | --- | --- |
| Metrics | Observability host pulls from app host | App exposes `/metrics`; firewall allows `monitored_service_metrics_target`. |
| Health probes | Observability host probes app host | App exposes a stable health URL for Blackbox Exporter. |
| Traces | App host pushes to observability host | App or sidecar collector exports OTLP to `4317` or `4318`. |
| Logs | App host pushes to observability host | App emits OTLP logs or an app-host collector tails journald and exports OTLP. |

## Observability Server

Put the live application details in `terraform/terraform.tfvars`:

```hcl
monitored_service_name = "personal-trainer-be"
monitored_service_metrics_target = "<be-server-private-ip-or-dns>:8080"
monitored_service_metrics_scheme = "http"
monitored_service_metrics_path = "/metrics"
monitored_service_health_url = "http://<be-server-private-ip-or-dns>:8080/api/v1/health"
monitored_service_systemd_unit = "personal-trainer-backend-staging.service"
collect_local_monitored_service_logs = false
```

For a public HTTPS endpoint, use `host:port` and set the scheme explicitly:

```hcl
monitored_service_metrics_target = "api.staging.fitcall.me:443"
monitored_service_metrics_scheme = "https"
monitored_service_metrics_path = "/metrics"
monitored_service_health_url = "https://api.staging.fitcall.me/api/v1/health"
```

The observability server must be able to reach the BE server on the metrics and
health-check port. The BE server must be able to reach the observability server
on OpenTelemetry Collector ports `4317` and, if using HTTP OTLP, `4318`.

After editing variables, apply the rendered config:

```bash
make up
make health
```

Confirm Prometheus sees the target:

```bash
curl -fsS http://localhost:9090/api/v1/targets
```

## BE Server

Recommended production shape: run an OpenTelemetry Collector agent on the BE
host, then point the BE process at the local agent. This keeps the application
stable even if the central observability host is temporarily unavailable, and it
lets the agent forward both traces and journald logs.

The app-host agent uses retrying OTLP exporters with a file-backed sending queue
under `/var/lib/otelcol-app-agent/file_storage`, so short network or central
collector interruptions are buffered instead of being dropped immediately.

Install the app-host agent on the BE server. One agent is enough even when
staging and production run on the same VM; by default the script collects both
backend systemd units:

```bash
SERVICE_NAME=personal-trainer-be \
CENTRAL_OTEL_ENDPOINT=<observability-server-private-ip-or-dns>:4317 \
scripts/app-host/install_otel_agent.sh
```

The default collected units are:

```bash
APP_SERVICE_UNITS=staging:personal-trainer-backend-staging.service,production:personal-trainer-backend-production.service
```

To collect only one environment, override `APP_SERVICE_UNITS`:

```bash
SERVICE_NAME=personal-trainer-be \
APP_SERVICE_UNITS=staging:personal-trainer-backend-staging.service \
CENTRAL_OTEL_ENDPOINT=<observability-server-private-ip-or-dns>:4317 \
scripts/app-host/install_otel_agent.sh
```

Configure the BE service environment to export traces to the local agent and
emit JSON logs:

```env
SERVICE_NAME=personal-trainer-be
OTEL_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=127.0.0.1:4317
LOG_FORMAT=json
```

Set `APP_ENV=staging` in the staging backend service and
`APP_ENV=production` in the production backend service. The backend tracer uses
`APP_ENV` as the trace `deployment.environment`; the app-host agent applies the
same environment labels to journald logs based on `APP_SERVICE_UNITS`.

Metrics are pulled by Prometheus from `monitored_service_metrics_target`. Traces
are pushed by the BE process to the local app-host Collector, then forwarded to
the central Collector and Tempo.

If the application does not emit OTLP traces yet, leave tracing disabled and
start with metrics plus Blackbox probes. The rest of the platform remains useful
for uptime, saturation, SLO burn, and DORA reporting.

The installer writes a Collector config equivalent to:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 127.0.0.1:4317
      http:
        endpoint: 127.0.0.1:4318

  journald/staging:
    directory: /var/log/journal
    units:
      - personal-trainer-backend-staging.service
    priority: info

  journald/production:
    directory: /var/log/journal
    units:
      - personal-trainer-backend-production.service
    priority: info

processors:
  batch:
  resource/staging:
    attributes:
      - key: service.name
        value: personal-trainer-be
        action: upsert
      - key: deployment.environment
        value: staging
        action: upsert
  resource/production:
    attributes:
      - key: service.name
        value: personal-trainer-be
        action: upsert
      - key: deployment.environment
        value: production
        action: upsert

exporters:
  otlp:
    endpoint: <observability-server-private-ip-or-dns>:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp]
    logs/staging:
      receivers: [journald/staging]
      processors: [resource/staging, batch]
      exporters: [otlp]
    logs/production:
      receivers: [journald/production]
      processors: [resource/production, batch]
      exporters: [otlp]
```

The central collector accepts OTLP logs and sends them to Loki.

## Viewing Service Status

Run these commands on the BE server.

Check the app-host OpenTelemetry Collector agent:

```bash
sudo systemctl status otelcol-app-agent.service --no-pager
```

Follow the agent logs:

```bash
sudo journalctl -u otelcol-app-agent.service -f
```

Check backend service status:

```bash
sudo systemctl status personal-trainer-backend-staging.service --no-pager
sudo systemctl status personal-trainer-backend-production.service --no-pager
```

If the host uses unit names without the `.service` suffix, this form also works:

```bash
sudo systemctl status personal-trainer-backend-staging --no-pager
sudo systemctl status personal-trainer-backend-production --no-pager
```

## Validation Checklist

- `up{job="<service-name>"}` is `1` in Prometheus.
- `probe_success{instance="<health-url>"}` is `1`.
- Grafana dashboards show the monitored service label.
- Loki receives logs with `service.name=<service-name>` when log shipping is enabled.
- Tempo receives traces with `service.name=<service-name>` when tracing is enabled.
- A forced failure or latency spike is visible in the Unified Observability dashboard.
