# MTTR Too High

## What this alert means

The average time to restore service is above the 30-minute objective.

## Likely causes

- Alerts lack context.
- Runbooks are incomplete.
- Rollback is manual or slow.
- Ownership is unclear during incidents.

## First 3 investigation steps

1. Review recent incidents and compare detection, acknowledgement, mitigation, and resolution times.
2. Identify where manual waiting occurred.
3. Confirm alerts include dashboard and runbook links.

## Resolution

- Automate the slowest manual recovery step.
- Improve runbooks and alert annotations.
- Add rollback or feature-disable automation.

## Rollback guidance

Rollback should be the default for confirmed deployment-caused incidents unless data loss or migration risk makes rollback unsafe.

## Escalation

Escalate to platform engineering and the service owner during review.
