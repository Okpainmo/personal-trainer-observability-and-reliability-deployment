#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:?REPO_ROOT is required}"
GENERATED_DIR="${GENERATED_DIR:?GENERATED_DIR is required}"
CONFIG_DIR="${CONFIG_DIR:-/etc/personal-trainer-observability}"
DATA_DIR="${DATA_DIR:-/var/lib/personal-trainer-observability}"
APP_DIR="${APP_DIR:-/opt/personal-trainer-observability}"
SERVICE_USER="${SERVICE_USER:-observability}"

sudo useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER" 2>/dev/null || true

sudo mkdir -p \
  "$CONFIG_DIR/prometheus/rules" \
  "$CONFIG_DIR/alertmanager/templates" \
  "$CONFIG_DIR/grafana/provisioning/datasources" \
  "$CONFIG_DIR/grafana/provisioning/dashboards" \
  "$CONFIG_DIR/grafana/dashboards" \
  "$CONFIG_DIR/loki" \
  "$CONFIG_DIR/tempo" \
  "$CONFIG_DIR/otel-collector" \
  "$CONFIG_DIR/blackbox" \
  "$CONFIG_DIR/secrets" \
  "$DATA_DIR/prometheus" \
  "$DATA_DIR/alertmanager" \
  "$DATA_DIR/loki" \
  "$DATA_DIR/tempo" \
  "$APP_DIR/services"

sudo cp "$REPO_ROOT/observability/prometheus/prometheus.yml" "$CONFIG_DIR/prometheus/prometheus.yml"
sudo cp "$REPO_ROOT/observability/prometheus/rules/"*.yml "$CONFIG_DIR/prometheus/rules/"
sudo cp "$REPO_ROOT/observability/alertmanager/alertmanager.yml" "$CONFIG_DIR/alertmanager/alertmanager.yml"
sudo cp "$REPO_ROOT/observability/alertmanager/templates/"*.tmpl "$CONFIG_DIR/alertmanager/templates/"
sudo cp "$REPO_ROOT/observability/loki/loki.yml" "$CONFIG_DIR/loki/loki.yml"
sudo cp "$REPO_ROOT/observability/tempo/tempo.yml" "$CONFIG_DIR/tempo/tempo.yml"
sudo cp "$REPO_ROOT/observability/otel-collector/config.yml" "$CONFIG_DIR/otel-collector/config.yml"
sudo cp "$REPO_ROOT/observability/blackbox/blackbox.yml" "$CONFIG_DIR/blackbox/blackbox.yml"
sudo cp "$REPO_ROOT/observability/grafana/provisioning/datasources/datasources.yml" "$CONFIG_DIR/grafana/provisioning/datasources/datasources.yml"
sudo cp "$REPO_ROOT/observability/grafana/provisioning/dashboards/dashboards.yml" "$CONFIG_DIR/grafana/provisioning/dashboards/dashboards.yml"
sudo cp "$REPO_ROOT/observability/grafana/dashboards/"*.json "$CONFIG_DIR/grafana/dashboards/"
sudo install -m 0600 "$GENERATED_DIR/slack_webhook_url" "$CONFIG_DIR/secrets/slack_webhook_url"
sudo install -m 0600 "$GENERATED_DIR/secrets/dora-exporter.env" "$CONFIG_DIR/secrets/dora-exporter.env"

sudo rsync -a --delete "$REPO_ROOT/services/trainer-api/" "$APP_DIR/services/trainer-api/"
sudo rsync -a --delete "$REPO_ROOT/services/dora-exporter/" "$APP_DIR/services/dora-exporter/"

sudo python3 -m venv "$APP_DIR/services/trainer-api/.venv"
sudo "$APP_DIR/services/trainer-api/.venv/bin/pip" install --upgrade pip
sudo "$APP_DIR/services/trainer-api/.venv/bin/pip" install -r "$APP_DIR/services/trainer-api/requirements.txt"

sudo python3 -m venv "$APP_DIR/services/dora-exporter/.venv"
sudo "$APP_DIR/services/dora-exporter/.venv/bin/pip" install --upgrade pip
sudo "$APP_DIR/services/dora-exporter/.venv/bin/pip" install -r "$APP_DIR/services/dora-exporter/requirements.txt"

sudo cp "$GENERATED_DIR/systemd/"*.service /etc/systemd/system/
sudo cp "$GENERATED_DIR/grafana/grafana.ini" /etc/grafana/grafana.ini
sudo rsync -a --delete "$CONFIG_DIR/grafana/provisioning/" /etc/grafana/provisioning/
sudo mkdir -p /var/lib/grafana/dashboards
sudo rsync -a --delete "$CONFIG_DIR/grafana/dashboards/" /var/lib/grafana/dashboards/

sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR" "$DATA_DIR"
sudo chown -R root:root "$CONFIG_DIR"
sudo chmod 0755 "$CONFIG_DIR" "$CONFIG_DIR"/{prometheus,alertmanager,grafana,loki,tempo,otel-collector,blackbox}
sudo chown "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR/secrets/slack_webhook_url" "$CONFIG_DIR/secrets/dora-exporter.env"
sudo chmod 0600 "$CONFIG_DIR/secrets/slack_webhook_url"
sudo chmod 0600 "$CONFIG_DIR/secrets/dora-exporter.env"

sudo systemctl daemon-reload
sudo systemctl enable --now \
  prometheus.service \
  alertmanager.service \
  loki.service \
  tempo.service \
  otel-collector.service \
  node-exporter.service \
  blackbox-exporter.service \
  trainer-api.service \
  dora-exporter.service \
  grafana-server.service

sudo systemctl restart \
  prometheus.service \
  alertmanager.service \
  loki.service \
  tempo.service \
  otel-collector.service \
  node-exporter.service \
  blackbox-exporter.service \
  trainer-api.service \
  dora-exporter.service \
  grafana-server.service

echo "bare-metal observability stack provisioned"
