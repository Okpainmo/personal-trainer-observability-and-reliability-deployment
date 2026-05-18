# Instance Down

## What this alert means

Blackbox Exporter could not successfully probe the target for at least two minutes.

## Likely causes

- Service process stopped.
- Container unhealthy or restarting.
- Network or DNS failure.
- Bad deployment.

## First 3 investigation steps

1. Open the Blackbox dashboard and confirm which target is failing.
2. Run `docker compose ps` and inspect the affected service logs.
3. Check recent deployment status in the DORA dashboard.

## Resolution

- Restart the service if it is crashed.
- Roll back the last deployment if the outage started after release.
- Fix network, DNS, or port binding issues if the process is healthy.

## Rollback guidance

Roll back immediately if the outage follows a deployment and health checks fail.

## Escalation

Escalate to platform engineering if multiple targets fail or host networking is suspected.
