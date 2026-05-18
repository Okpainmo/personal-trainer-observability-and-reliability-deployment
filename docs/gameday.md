# Game Day Scenarios

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
