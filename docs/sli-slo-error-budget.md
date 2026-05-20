# SLIs, SLOs, and Error Budgets

Measurement window: 30 days.

Metrics retention: 30 days in Prometheus.

Log and trace retention: 7 days in Loki and Tempo.

Primary service label: the configured `monitored_service_name` Terraform value.
The bundled `test-api` can be used to validate these queries, but production
SLOs should be evaluated against the real monitored service.

## Four Golden Signal SLIs

### Latency

Successful request p95 latency:

```promql
histogram_quantile(
  0.95,
  sum(rate(http_request_duration_seconds_bucket{status!~"5.."}[5m])) by (le)
)
```

Error request p95 latency:

```promql
histogram_quantile(
  0.95,
  sum(rate(http_request_duration_seconds_bucket{status=~"5.."}[5m])) by (le)
)
```

SLO: 95% of successful requests should complete under 500ms.

Rationale: this is strict enough to expose user-visible slowness while allowing short local-development and service startup variance.

Implementation note: the monitored service must expose Prometheus histogram
buckets named `http_request_duration_seconds_bucket` for this exact query. If
the application exports a different metric name, update dashboards and rules
together.

### Traffic

Requests per second:

```promql
sum(rate(http_requests_total[5m])) by (service)
```

SLO: the platform must keep dashboards and alerts accurate at the observed traffic level.

Rationale: traffic is not usually an objective by itself; it explains changes in latency, errors, and saturation.

### Errors

5xx error ratio:

```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
/
sum(rate(http_requests_total[5m])) by (service)
```

SLO: 99.5% of requests should avoid 5xx responses over 30 days.

Rationale: the demo service is simple, so a 0.5% error budget is reasonable without overpromising 99.99%.

### Saturation

CPU utilization:

```promql
1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

Memory utilization:

```promql
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

Disk utilization:

```promql
1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"})
```

SLO: infrastructure saturation should stay below critical thresholds during normal operation.

Rationale: saturation is a leading indicator; it predicts reliability loss before users see hard failures.

## Availability SLO

```promql
avg_over_time(probe_success{job="blackbox-http"}[30d])
```

Target: 99.5% of probes return success over 30 days.

Error budget:

```text
(1 - 0.995) * 30 days = 0.15 days = 3.6 hours
```

## Burn-rate thresholds

Fast burn:

```promql
job:http_error_ratio:rate1h{service="<monitored_service_name>"} > (14.4 * 0.005)
```

Slow burn:

```promql
job:http_error_ratio:rate6h{service="<monitored_service_name>"} > (5 * 0.005)
```

## Alert Response

- Fast burn means user impact is accumulating quickly. Treat it as an incident and start with [SLO burn runbook](../runbooks/slo-burn.md).
- Slow burn means the budget is being consumed over a longer window. Review recent deployments, error logs, and saturation before approving more risky changes.
- If the budget reaches 100% consumed, follow the [error budget policy](error-budget-policy.md) before resuming normal delivery.
