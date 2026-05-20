#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-personal-trainer-be}"
# Comma-separated environment:systemd-unit pairs. One agent can collect logs
# for multiple backend units on the same VM while sharing one local OTLP
# receiver for traces from all of them.
APP_SERVICE_UNITS="${APP_SERVICE_UNITS:-staging:personal-trainer-backend-staging.service,production:personal-trainer-backend-production.service}"
CENTRAL_OTEL_ENDPOINT="${CENTRAL_OTEL_ENDPOINT:?CENTRAL_OTEL_ENDPOINT is required, for example 10.0.1.10:4317}"
OTELCOL_VERSION="${OTELCOL_VERSION:-0.110.0}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/otelcol-app-agent}"
DATA_DIR="${DATA_DIR:-/var/lib/otelcol-app-agent}"
WORK_DIR="${WORK_DIR:-/var/tmp/otelcol-app-agent-install}"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) go_arch="amd64" ;;
  aarch64|arm64) go_arch="arm64" ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

sudo mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR/file_storage" "$WORK_DIR"
sudo chown "$(id -u):$(id -g)" "$WORK_DIR"

archive="$WORK_DIR/otelcol-contrib_${OTELCOL_VERSION}_linux_${go_arch}.tar.gz"
if [ ! -f "$archive" ]; then
  curl --fail --location --show-error --progress-bar \
    --connect-timeout 30 \
    --retry 3 \
    --retry-delay 5 \
    --max-time 900 \
    "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_linux_${go_arch}.tar.gz" \
    -o "$archive"
fi

tar -xzf "$archive" -C "$WORK_DIR"
sudo install -m 0755 "$WORK_DIR/otelcol-contrib" "$BIN_DIR/otelcol-contrib"

tmp_config="$(mktemp)"
receivers_file="$(mktemp)"
processors_file="$(mktemp)"
pipelines_file="$(mktemp)"

cat >"$tmp_config" <<'EOF_CONFIG'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 127.0.0.1:4317
      http:
        endpoint: 127.0.0.1:4318
EOF_CONFIG

cat >"$processors_file" <<'EOF_PROCESSORS'
processors:
  batch:
EOF_PROCESSORS

cat >"$pipelines_file" <<'EOF_PIPELINES'
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/central]
    logs/otlp:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/central]
EOF_PIPELINES

after_units=()
IFS=',' read -r -a service_pairs <<< "$APP_SERVICE_UNITS"
if [ "${#service_pairs[@]}" -eq 0 ]; then
  echo "APP_SERVICE_UNITS must include at least one environment:systemd-unit pair" >&2
  exit 1
fi

for pair in "${service_pairs[@]}"; do
  pair="$(echo "$pair" | xargs)"
  [ -n "$pair" ] || continue

  environment="${pair%%:*}"
  unit="${pair#*:}"
  if [ -z "$environment" ] || [ -z "$unit" ] || [ "$environment" = "$unit" ]; then
    echo "invalid APP_SERVICE_UNITS entry: $pair" >&2
    echo "expected format: staging:personal-trainer-backend-staging.service,production:personal-trainer-backend-production.service" >&2
    exit 1
  fi

  pipeline_suffix="$(printf '%s' "$environment" | tr -c '[:alnum:]_' '_')"
  after_units+=("$unit")

  cat >>"$receivers_file" <<EOF_RECEIVER

  journald/${pipeline_suffix}:
    directory: /var/log/journal
    units:
      - ${unit}
    priority: info
EOF_RECEIVER

  cat >>"$processors_file" <<EOF_PROCESSOR

  resource/${pipeline_suffix}:
    attributes:
      - key: service.name
        value: ${SERVICE_NAME}
        action: upsert
      - key: deployment.environment
        value: ${environment}
        action: upsert
EOF_PROCESSOR

  cat >>"$pipelines_file" <<EOF_PIPELINE
    logs/journald-${pipeline_suffix}:
      receivers: [journald/${pipeline_suffix}]
      processors: [resource/${pipeline_suffix}, batch]
      exporters: [otlp/central]
EOF_PIPELINE
done

cat "$receivers_file" >>"$tmp_config"
cat "$processors_file" >>"$tmp_config"
cat >>"$tmp_config" <<'EOF_CONFIG'

extensions:
  file_storage:
    directory: __DATA_DIR__/file_storage

exporters:
  otlp/central:
    endpoint: __CENTRAL_OTEL_ENDPOINT__
    tls:
      insecure: true
    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 30s
      max_elapsed_time: 0s
    sending_queue:
      enabled: true
      num_consumers: 4
      queue_size: 10000
      storage: file_storage

service:
  extensions: [file_storage]
  telemetry:
    metrics:
      address: 127.0.0.1:8888
  pipelines:
EOF_CONFIG
cat "$pipelines_file" >>"$tmp_config"
rm -f "$receivers_file" "$processors_file" "$pipelines_file"

sed -i \
  -e "s#__DATA_DIR__#${DATA_DIR}#g" \
  -e "s#__CENTRAL_OTEL_ENDPOINT__#${CENTRAL_OTEL_ENDPOINT}#g" \
  "$tmp_config"
sudo install -m 0644 "$tmp_config" "$CONFIG_DIR/config.yml"
rm -f "$tmp_config"

tmp_unit="$(mktemp)"
after_units_text="${after_units[*]}"
cat >"$tmp_unit" <<EOF_UNIT
[Unit]
Description=OpenTelemetry App Host Agent
Wants=network-online.target
After=network-online.target ${after_units_text}

[Service]
User=root
Group=root
Type=simple
ExecStart=${BIN_DIR}/otelcol-contrib --config=${CONFIG_DIR}/config.yml
Restart=always
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF_UNIT
sudo install -m 0644 "$tmp_unit" /etc/systemd/system/otelcol-app-agent.service
rm -f "$tmp_unit"

sudo systemctl daemon-reload
sudo systemctl enable --now otelcol-app-agent.service
sudo systemctl restart otelcol-app-agent.service

echo "otelcol app-host agent installed"
echo "backend OTEL_EXPORTER_OTLP_ENDPOINT should be 127.0.0.1:4317"
echo "collecting journald units: ${APP_SERVICE_UNITS}"
