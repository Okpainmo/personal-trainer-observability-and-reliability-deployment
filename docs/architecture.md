# Bare-Metal Architecture

## LGTM data flow

```mermaid
flowchart LR
  U[User or Blackbox probe] --> API[trainer-api systemd service]
  API -->|/metrics on :8080| P[Prometheus]
  API -->|OTLP traces to :4317| OTel[OpenTelemetry Collector]
  Journal[journald] -->|systemd service logs| OTel
  OTel -->|OTLP logs| Loki[Loki :3100]
  OTel -->|OTLP traces to :4319| Tempo[Tempo :3200]
  NE[Node Exporter :9100] --> P
  BB[Blackbox Exporter :9115] --> P
  Dora[DORA Exporter :9108] --> P
  P --> AM[Alertmanager :9093]
  AM --> Slack[#detrudr-alerts-demo]
  Grafana[Grafana :3000] --> P
  Grafana --> Loki
  Grafana --> Tempo
```

## Terraform provisioning flow

```mermaid
flowchart TD
  TF[terraform apply] --> Render[Render secrets, Grafana config, and systemd units]
  Render --> Install[Install binaries if install_binaries=true]
  Install --> Copy[Copy configs to /etc/personal-trainer-observability]
  Copy --> Venv[Create Python virtualenvs]
  Venv --> Systemd[systemctl enable --now services]
  Systemd --> Stack[LGTM stack, exporters, app, DORA exporter]
```

## Reliability pipeline

```mermaid
flowchart TD
  Telemetry[Metrics, logs, traces] --> SLIs[Four Golden Signal SLIs]
  SLIs --> SLOs[SLO targets]
  SLOs --> Budget[Error budget]
  Budget --> Burn[Burn-rate alerts]
  Burn --> AM[Alertmanager routing and inhibition]
  AM --> Slack[Structured Slack payload]
  Slack --> Runbook[Runbook and escalation]
```

## Drill-down path

```mermaid
sequenceDiagram
  participant Engineer
  participant Grafana
  participant Prometheus
  participant Loki
  participant Tempo

  Engineer->>Grafana: Open Unified Observability dashboard
  Grafana->>Prometheus: Query latency or error spike
  Engineer->>Grafana: Select the same time range
  Grafana->>Loki: Query logs with trace_id
  Engineer->>Grafana: Click trace_id
  Grafana->>Tempo: Open matching trace
  Tempo-->>Engineer: Slow or failing span
```

## Filesystem layout

```text
/etc/personal-trainer-observability/
  prometheus/
  alertmanager/
  grafana/
  loki/
  tempo/
  otel-collector/
  blackbox/
  secrets/

/var/lib/personal-trainer-observability/
  prometheus/
  alertmanager/
  loki/
  tempo/

/opt/personal-trainer-observability/
  services/trainer-api/
  services/dora-exporter/
```
