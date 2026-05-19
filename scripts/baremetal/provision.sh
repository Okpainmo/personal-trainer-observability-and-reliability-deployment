#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:?REPO_ROOT is required}"
GENERATED_DIR="${GENERATED_DIR:?GENERATED_DIR is required}"
CONFIG_DIR="${CONFIG_DIR:-/etc/observability-platform}"
DATA_DIR="${DATA_DIR:-/var/lib/observability-platform}"
APP_DIR="${APP_DIR:-/opt/observability-platform}"
SERVICE_USER="${SERVICE_USER:-observability}"
DEPLOY_TEST_API="${DEPLOY_TEST_API:-false}"

require_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "required generated file is missing: $path" >&2
    echo "rerun: terraform -chdir=terraform apply -auto-approve" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [ ! -d "$path" ]; then
    echo "required generated directory is missing: $path" >&2
    echo "rerun: terraform -chdir=terraform apply -auto-approve" >&2
    exit 1
  fi
}

require_file "$GENERATED_DIR/slack_webhook_url"
require_file "$GENERATED_DIR/secrets/dora-exporter.env"
require_file "$GENERATED_DIR/grafana/grafana.ini"
require_file "$GENERATED_DIR/prometheus/prometheus.yml"
require_file "$GENERATED_DIR/otel-collector/config.yml"
require_dir "$GENERATED_DIR/systemd"

sudo useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER" 2>/dev/null || true

# Remove the legacy built-in demo service name from earlier revisions.
sudo systemctl disable --now trainer-api.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/trainer-api.service
sudo rm -rf "$APP_DIR/services/trainer-api"

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

sudo cp "$GENERATED_DIR/prometheus/prometheus.yml" "$CONFIG_DIR/prometheus/prometheus.yml"
sudo cp "$REPO_ROOT/observability/prometheus/rules/"*.yml "$CONFIG_DIR/prometheus/rules/"
sudo cp "$REPO_ROOT/observability/alertmanager/alertmanager.yml" "$CONFIG_DIR/alertmanager/alertmanager.yml"
sudo cp "$REPO_ROOT/observability/alertmanager/templates/"*.tmpl "$CONFIG_DIR/alertmanager/templates/"
sudo cp "$REPO_ROOT/observability/loki/loki.yml" "$CONFIG_DIR/loki/loki.yml"
sudo cp "$REPO_ROOT/observability/tempo/tempo.yml" "$CONFIG_DIR/tempo/tempo.yml"
sudo cp "$GENERATED_DIR/otel-collector/config.yml" "$CONFIG_DIR/otel-collector/config.yml"
sudo cp "$REPO_ROOT/observability/blackbox/blackbox.yml" "$CONFIG_DIR/blackbox/blackbox.yml"
sudo cp "$REPO_ROOT/observability/grafana/provisioning/datasources/datasources.yml" "$CONFIG_DIR/grafana/provisioning/datasources/datasources.yml"
sudo cp "$REPO_ROOT/observability/grafana/provisioning/dashboards/dashboards.yml" "$CONFIG_DIR/grafana/provisioning/dashboards/dashboards.yml"
sudo cp "$REPO_ROOT/observability/grafana/dashboards/"*.json "$CONFIG_DIR/grafana/dashboards/"
sudo install -m 0600 "$GENERATED_DIR/slack_webhook_url" "$CONFIG_DIR/secrets/slack_webhook_url"
sudo install -m 0600 "$GENERATED_DIR/secrets/dora-exporter.env" "$CONFIG_DIR/secrets/dora-exporter.env"

if [ "$DEPLOY_TEST_API" = "true" ]; then
  sudo rsync -a --delete "$REPO_ROOT/services/test-api/" "$APP_DIR/services/test-api/"
else
  sudo systemctl disable --now test-api.service 2>/dev/null || true
  sudo rm -f /etc/systemd/system/test-api.service
  sudo rm -rf "$APP_DIR/services/test-api"
fi
sudo rsync -a --delete "$REPO_ROOT/services/dora-exporter/" "$APP_DIR/services/dora-exporter/"

if [ "$DEPLOY_TEST_API" = "true" ]; then
  sudo python3 -m venv "$APP_DIR/services/test-api/.venv"
  sudo "$APP_DIR/services/test-api/.venv/bin/pip" install --upgrade pip
  sudo "$APP_DIR/services/test-api/.venv/bin/pip" install -r "$APP_DIR/services/test-api/requirements.txt"
fi

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
services_to_manage=(
  prometheus.service
  alertmanager.service
  loki.service
  tempo.service
  otel-collector.service
  node-exporter.service
  blackbox-exporter.service
  dora-exporter.service
  grafana-server.service
)

if [ "$DEPLOY_TEST_API" = "true" ]; then
  services_to_manage+=(test-api.service)
fi

sudo systemctl enable --now "${services_to_manage[@]}"
sudo systemctl restart "${services_to_manage[@]}"

echo "bare-metal observability stack provisioned"
