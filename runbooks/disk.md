# Disk Saturation

## What this alert means

Disk usage has crossed the warning or critical threshold. At critical levels, Prometheus, Loki, Tempo, or application writes may fail.

## Likely causes

- Log volume spike.
- Retention misconfiguration.
- Large Docker images or unused containers.
- Application writing unexpected files.

## First 3 investigation steps

1. Open the Node Exporter dashboard and identify the affected mountpoint.
2. Check Docker disk usage with `docker system df`.
3. Inspect Loki and Prometheus retention settings before deleting data.

## Resolution

- Remove unused Docker images, containers, or volumes only after confirming they are safe.
- Shorten retention if the environment is undersized.
- Move persistent data to a larger disk.

## Rollback guidance

Rollback is useful only when a deployment caused abnormal log or file growth.

## Escalation

Escalate to platform engineering if persistent telemetry data is at risk.
