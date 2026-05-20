# DORA Metrics

The DORA exporter exposes Prometheus metrics on port `9108`.

When `GITHUB_REPOSITORY`, `GITHUB_TOKEN`, and `DEPLOYMENT_WORKFLOW_NAME` are set, it reads GitHub Actions workflow runs. Without credentials, it emits deterministic fallback data so dashboards can load locally.

Terraform writes those values into `terraform/.generated/secrets/dora-exporter.env`
from:

- `github_repository`
- `github_token`
- `deployment_workflow_name`
- `monitored_service_name`

The rendered env file is copied to the host during provisioning and consumed by
`dora-exporter.service`.

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

## MTTR Source

MTTR is calculated from the incidents file used by the exporter. The example
shape lives at `services/dora-exporter/incidents.example.json`. Keep incident
timestamps consistent and use the post-incident review template in
`docs/post-incident-review.md` for human-readable incident records.

## Operating Notes

- Use a GitHub token with the smallest scope that can read Actions workflow runs.
- If the token or repository is blank, expect fallback demo values instead of live delivery metrics.
- A failed or cancelled deployment contributes to change failure rate.
- The DORA dashboard is a delivery-health signal; it should be reviewed with SLO and incident data, not in isolation.
