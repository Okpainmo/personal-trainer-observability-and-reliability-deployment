#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/personal-trainer-observability}"
DATA_DIR="${DATA_DIR:-/var/lib/personal-trainer-observability}"
APP_DIR="${APP_DIR:-/opt/personal-trainer-observability}"

services=(
  prometheus.service
  alertmanager.service
  loki.service
  tempo.service
  otel-collector.service
  node-exporter.service
  blackbox-exporter.service
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
