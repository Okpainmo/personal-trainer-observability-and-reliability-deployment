# Blameless Post-Incident Review

Incident: simulated latency degradation on `test-api`.

Date: 2026-05-18.

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

## Detection gaps

The alert only fires after the configured `for` duration, which is intentional to avoid flapping. For extremely short spikes, dashboards reveal the issue before alerts.

## Action items

- Owner: platform engineering. Add synthetic latency checks for the highest-value endpoint. Due: 2026-05-25.
- Owner: service team. Add timeout protection around slow dependencies. Due: 2026-05-25.
- Owner: platform engineering. Review burn-rate thresholds after one week of traffic. Due: 2026-05-25.
