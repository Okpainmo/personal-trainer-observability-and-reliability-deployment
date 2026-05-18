# Memory Saturation

## What this alert means

Available memory is low enough to risk swapping, OOM kills, or degraded request latency.

## Likely causes

- Memory leak.
- Increased traffic.
- Oversized batch job.
- Container memory limits missing or too high.

## First 3 investigation steps

1. Open the Node Exporter dashboard and inspect used, cached, and available memory.
2. Run `docker stats` to find the largest memory consumer.
3. Check Loki for OOM or application error logs.

## Resolution

- Restart the leaking service if needed.
- Reduce or stop background workload.
- Add memory limits and tune application allocation.

## Rollback guidance

Roll back if memory growth began immediately after deployment and continues after traffic normalizes.

## Escalation

Escalate to the service owner for leaks and to platform engineering for host capacity issues.
