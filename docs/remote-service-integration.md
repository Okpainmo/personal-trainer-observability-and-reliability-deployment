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
monitored_service_health_url = "http://<be-server-private-ip-or-dns>:8080/api/v1/health"
monitored_service_systemd_unit = "personal-trainer-be.service"
collect_local_monitored_service_logs = false
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

Configure the BE service environment:

```env
SERVICE_NAME=personal-trainer-be
OTEL_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=<observability-server-private-ip-or-dns>:4317
LOG_FORMAT=json
```

Metrics are pulled by Prometheus from `monitored_service_metrics_target`. Traces
are pushed by the BE process to the central OpenTelemetry Collector.

If the application does not emit OTLP traces yet, leave tracing disabled and
start with metrics plus Blackbox probes. The rest of the platform remains useful
for uptime, saturation, SLO burn, and DORA reporting.

For remote journald logs, run an OpenTelemetry Collector agent on the BE server
and export logs to the central collector:

```yaml
receivers:
  journald:
    directory: /var/log/journal
    units:
      - personal-trainer-be.service
    priority: info

processors:
  batch:
  resource:
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
    logs:
      receivers: [journald]
      processors: [resource, batch]
      exporters: [otlp]
```

The central collector accepts OTLP logs and sends them to Loki.

## Validation Checklist

- `up{job="<service-name>"}` is `1` in Prometheus.
- `probe_success{instance="<health-url>"}` is `1`.
- Grafana dashboards show the monitored service label.
- Loki receives logs with `service.name=<service-name>` when log shipping is enabled.
- Tempo receives traces with `service.name=<service-name>` when tracing is enabled.
- A forced failure or latency spike is visible in the Unified Observability dashboard.
