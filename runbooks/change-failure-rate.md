# Change Failure Rate

## What this alert means

Too many recent deployments are failing, rolling back, or requiring hotfixes.

## Likely causes

- Weak pre-deployment validation.
- Flaky deployment workflow.
- Missing rollback automation.
- Unsafe release batching.

## First 3 investigation steps

1. Open the DORA dashboard and inspect deployment outcomes.
2. Open GitHub Actions and identify the failing workflow stage.
3. Check recent incident records and deployment timestamps.

## Resolution

- Fix the failing deployment stage.
- Reduce release batch size.
- Add automated checks for the repeated failure mode.

## Rollback guidance

Roll back user-facing failed releases; do not roll back purely internal CI failures unless production changed.

## Escalation

Escalate to the release owner and platform engineering.
