#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/observability-platform}"
DATA_DIR="${DATA_DIR:-/var/lib/observability-platform}"
APP_DIR="${APP_DIR:-/opt/observability-platform}"

services=(
  prometheus.service
  alertmanager.service
  loki.service
  tempo.service
  otel-collector.service
  node-exporter.service
  blackbox-exporter.service
  test-api.service
  trainer-api.service
  dora-exporter.service
)

for service in "${services[@]}"; do
  sudo systemctl disable --now "$service" 2>/dev/null || true
  sudo rm -f "/etc/systemd/system/$service"
done

sudo systemctl daemon-reload
sudo rm -rf "$CONFIG_DIR" "$DATA_DIR" "$APP_DIR"

echo "bare-metal observability stack removed"
