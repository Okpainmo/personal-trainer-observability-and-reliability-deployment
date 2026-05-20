# Toil and Automation

This document tracks repetitive operational work that the platform should remove
or reduce. A task counts as toil when it is manual, repetitive, automatable,
tactical, and grows with the number of services or incidents.

## Toil 1: Manual dashboard creation

Manual Grafana work is slow and easy to lose. This repo provisions every datasource and dashboard from files under `observability/grafana`.

Automation implemented: dashboard and datasource provisioning as code.

## Toil 2: Manual SSL and uptime checks

Engineers should not manually check uptime or certificate expiry.

Automation implemented: Blackbox Exporter probes service availability and SSL expiry, with Prometheus alerts and dashboard panels.

## Toil 3: Manual incident context gathering

Copying metric timestamps into log and trace tools wastes response time.

Automation implemented: the Loki datasource has derived fields that turn `trace_id` values in logs into direct Tempo links.

## Toil 4: Manual service provisioning

Hand-copying config files and unit files leads to drift between hosts.

Automation implemented: Terraform renders configuration and systemd units from
repository templates, then provisioning scripts copy them into the standard
host paths and restart services.

## Toil 5: Manual reliability reporting

Manually calculating deployment frequency, lead time, change failure rate, MTTR,
SLO compliance, and error-budget burn is slow and inconsistent.

Automation implemented: DORA Exporter and Prometheus recording/alerting rules
publish those values continuously for Grafana dashboards and Slack alerts.

## Backlog Candidates

- Add synthetic checks for the most important user journeys, not only health endpoints.
- Add dashboard linting or schema validation beyond JSON syntax checks.
- Add automated alert tests for every rule expression.
- Add an app-host collector install profile for remote services.
