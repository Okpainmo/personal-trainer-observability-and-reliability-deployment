# Blameless Post-Incident Review

Use this template for real incidents and game-day exercises. Keep it blameless,
specific, and tied to observable evidence from Grafana, Prometheus, Loki, Tempo,
Alertmanager, and DORA metrics.

## Incident Summary

Incident: simulated latency degradation on `test-api`.

Date: 2026-05-18.

Service: `test-api`.

Severity: SEV-3.

Status: resolved.

## Timeline

- 07:00 WAT: latency injection started with `/workout?delay_ms=1200`.
- 07:02 WAT: p95 latency rose on Unified Observability dashboard.
- 07:05 WAT: error-budget burn investigation started.
- 07:08 WAT: logs with `trace_id` were opened in Loki.
- 07:10 WAT: matching trace was opened in Tempo and showed the delayed span.
- 07:18 WAT: latency injection stopped and service recovered.

## Root cause

The service intentionally slept during the `build_workout_plan` span to simulate a slow dependency or expensive code path.

## Impact

Users experienced slow workout generation responses during the simulation window.

## Detection

- Dashboard: Unified Observability showed p95 latency increase.
- Logs: Loki entries included `trace_id` values for affected requests.
- Traces: Tempo showed the delayed span.
- Alerts: burn-rate alerts were expected only if the condition lasted beyond the configured `for` duration.

## Detection gaps

The alert only fires after the configured `for` duration, which is intentional to avoid flapping. For extremely short spikes, dashboards reveal the issue before alerts.

## What went well

- Metrics, logs, and traces could be correlated from Grafana.
- The delayed span was visible in Tempo.
- The exercise validated the dashboard-to-runbook investigation path.

## What could improve

- Add synthetic checks for the highest-value endpoints.
- Confirm burn-rate thresholds after observing real traffic.
- Make sure service owners know where to find linked runbooks during an alert.

## Action items

- Owner: platform engineering. Add synthetic latency checks for the highest-value endpoint. Due: 2026-05-25.
- Owner: service team. Add timeout protection around slow dependencies. Due: 2026-05-25.
- Owner: platform engineering. Review burn-rate thresholds after one week of traffic. Due: 2026-05-25.

## Follow-up Review

Review action items in the next reliability review. Update the relevant runbook,
dashboard, alert rule, or SLO document if the incident exposed a documentation
or tooling gap.
