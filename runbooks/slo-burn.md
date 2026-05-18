# SLO Error Budget Burn

## What this alert means

The service is consuming its 30-day error budget too quickly. Fast burn is critical; slow burn is warning-level degradation that needs attention.

## Likely causes

- Elevated 5xx errors.
- Latency causing client timeouts.
- Bad deployment.
- Downstream dependency failure.

## First 3 investigation steps

1. Open the SLO & Error Budget dashboard and compare fast and slow burn rates.
2. Open Unified Observability and inspect error rate, latency, logs, and traces for the same time window.
3. Check DORA dashboard for recent deployments.

## Resolution

- Roll back if a deployment introduced the burn.
- Disable the failing feature path if available.
- Scale or fix the saturated dependency.

## Rollback guidance

Roll back on fast burn when the causing deployment is known or strongly correlated.

## Escalation

Escalate immediately to the service owner and platform engineering for fast burn. Slow burn should be reviewed during the same business day.
