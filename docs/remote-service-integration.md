# Remote Service Integration

Use this when the monitored application runs on a different server from the
observability stack.

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
