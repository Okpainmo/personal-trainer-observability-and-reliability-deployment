# Toil and Automation

## Toil 1: Manual dashboard creation

Manual Grafana work is slow and easy to lose. This repo provisions every datasource and dashboard from files under `observability/grafana`.

Automation implemented: dashboard and datasource provisioning as code.

## Toil 2: Manual SSL and uptime checks

Engineers should not manually check uptime or certificate expiry.

Automation implemented: Blackbox Exporter probes service availability and SSL expiry, with Prometheus alerts and dashboard panels.

## Toil 3: Manual incident context gathering

Copying metric timestamps into log and trace tools wastes response time.

Automation implemented: the Loki datasource has derived fields that turn `trace_id` values in logs into direct Tempo links.
