# Error Budget Policy

Owner: platform engineering and the service owner for `test-api`.

Review cadence: weekly during delivery, monthly for target recalibration.

SLO window: rolling 30 days.

Availability target: 99.5%.

Allowed monthly unreliability: 3.6 hours.

## Budget actions

0-49% consumed:

- Normal delivery continues.
- Reliability work is prioritized through normal backlog ordering.

50-99% consumed:

- Platform and service owner review the top error sources.
- New risky releases require explicit owner approval.
- At least one reliability improvement is scheduled before the next feature release.

100% consumed:

- Feature freeze for the affected service.
- Work shifts to reliability recovery, rollback, or mitigation.
- SLO and incident review must happen before normal delivery resumes.

## Release Gates

- Before releasing, check the SLO & Error Budget dashboard for the affected service.
- If budget consumption is above 50%, the service owner must explicitly accept the release risk.
- If budget consumption is at or above 100%, only reliability fixes, rollbacks, or mitigations should ship.
- Emergency security fixes can bypass the freeze, but the incident review must record the decision.

## Decision ownership

The service owner decides release risk with input from platform engineering. Platform engineering owns alert quality, dashboards, and the error-budget calculation.

## Review Inputs

- SLO burn alerts and alert history.
- Unified Observability dashboard for latency, error, traffic, and saturation trends.
- Loki logs and Tempo traces for the highest-impact failures.
- DORA dashboard for recent deployments and change failure rate.
- Post-incident review notes for repeated causes.
