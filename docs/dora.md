# DORA Metrics

The DORA exporter exposes Prometheus metrics on port `9108`.

When `GITHUB_REPOSITORY`, `GITHUB_TOKEN`, and `DEPLOYMENT_WORKFLOW_NAME` are set, it reads GitHub Actions workflow runs. Without credentials, it emits deterministic fallback data so dashboards can load locally.

## Metrics

- `dora_deployments_total{conclusion}`: deployment count by outcome.
- `dora_last_deployment_timestamp_seconds{conclusion}`: timestamp of latest deployment by outcome.
- `dora_lead_time_seconds`: latest successful commit-to-deployment duration.
- `dora_change_failure_rate_ratio`: failed or cancelled deployments divided by all deployments.
- `dora_mttr_seconds`: average incident restoration duration from the incidents file.

## Classification

The dashboard classifies deployment frequency using the common DORA bands:

- Elite: one or more deploys per day.
- High: between daily and weekly.
- Medium: between weekly and monthly.
- Low: less than monthly.
