# Game Day Scenarios

Game days validate that the platform detects, routes, and explains failures
before real users depend on the monitored service. Run them first against
`test-api`, then adapt the same checks for the real service.

## Prerequisites

- `make up` has completed successfully.
- Grafana, Prometheus, Loki, Tempo, Alertmanager, and DORA Exporter are healthy.
- Slack webhook is configured if alert delivery is part of the test.
- `deploy_test_api = true` for scenarios that call `/workout`.

## Scenario 1: Deployment failure

Use `.github/workflows/failing-deployment.yml` or trigger a failing deployment workflow manually.

Expected result:

- DORA exporter observes failed workflow runs when `GITHUB_TOKEN` and `GITHUB_REPOSITORY` are configured.
- Change Failure Rate increases.
- `ChangeFailureRateTooHigh` fires if CFR exceeds 15%.
- Slack receives firing and resolved payloads through Alertmanager.

## Scenario 2: Latency injection

Command:

```bash
make gameday-latency
```

Expected result:

- p95 latency increases on the Unified Observability dashboard.
- Logs appear in Loki with a `trace_id`.
- The `trace_id` opens the matching Tempo trace.
- Sustained failures or errors consume error budget and trigger burn-rate alerts.

## Scenario 3: Resource pressure

Command:

```bash
make gameday-cpu
```

Expected result:

- Node Exporter CPU panels rise.
- CPU warning fires before critical if pressure remains long enough.
- Resolved notification is sent when pressure clears.

## Exit Criteria

- The symptom appears on the expected Grafana dashboard.
- The alert fires only when the documented threshold is crossed.
- Slack includes the service, severity, value, dashboard link, and runbook link.
- The runbook leads to a concrete diagnosis or mitigation.
- The alert resolves after the injected condition clears.
- Any confusing dashboard, alert, or runbook behavior becomes a follow-up item.
