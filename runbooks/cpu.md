# CPU Saturation

## What this alert means

CPU usage on the host has stayed above the warning or critical threshold long enough to risk request latency, timeouts, or process starvation.

## Likely causes

- Traffic spike.
- Expensive application code path.
- Background job or container consuming CPU.
- Runaway process on the host.

## First 3 investigation steps

1. Open the Node Exporter dashboard and compare total CPU, per-core CPU, and load average.
2. Run `docker stats` and identify the container consuming CPU.
3. Check the Unified Observability dashboard for matching latency or error-rate changes.

## Resolution

- Scale or restart the offending service if safe.
- Stop nonessential workload.
- Roll back if CPU rose immediately after a deployment.

## Rollback guidance

Roll back when CPU saturation correlates with a new release and user-facing latency or error SLIs are degraded.

## Escalation

Escalate to the service owner for application hotspots and to platform engineering for host-level saturation.
