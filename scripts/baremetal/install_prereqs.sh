#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-2.54.1}"
ALERTMANAGER_VERSION="${ALERTMANAGER_VERSION:-0.27.0}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
BLACKBOX_EXPORTER_VERSION="${BLACKBOX_EXPORTER_VERSION:-0.25.0}"
LOKI_VERSION="${LOKI_VERSION:-3.2.0}"
TEMPO_VERSION="${TEMPO_VERSION:-2.6.0}"
OTELCOL_VERSION="${OTELCOL_VERSION:-0.110.0}"
GRAFANA_VERSION="${GRAFANA_VERSION:-11.2.0}"

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
WORK_DIR="${WORK_DIR:-/tmp/personal-trainer-observability-install}"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) go_arch="amd64"; deb_arch="amd64" ;;
  aarch64|arm64) go_arch="arm64"; deb_arch="arm64" ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

sudo mkdir -p "$BIN_DIR" "$WORK_DIR"

package_manager=""
if command -v apt-get >/dev/null 2>&1; then
  package_manager="apt"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl tar unzip rsync python3 python3-venv python3-pip systemd stress-ng
elif command -v yum >/dev/null 2>&1; then
  package_manager="yum"
  sudo yum install -y ca-certificates curl tar unzip rsync python3 python3-pip systemd stress-ng
else
  echo "install curl, tar, unzip, rsync, python3, python3-venv, and systemd before running Terraform" >&2
  exit 1
fi

download() {
  local url="$1"
  local dest="$2"
  if [ ! -f "$dest" ]; then
    curl -fsSL "$url" -o "$dest"
  fi
}

install_tar_binary() {
  local name="$1"
  local version="$2"
  local url="$3"
  local binary="$4"
  local archive="$WORK_DIR/${name}-${version}.tar.gz"
  download "$url" "$archive"
  tar -xzf "$archive" -C "$WORK_DIR"
  local extracted
  extracted="$(find "$WORK_DIR" -maxdepth 2 -type f -name "$binary" | head -n 1)"
  sudo install -m 0755 "$extracted" "$BIN_DIR/$binary"
}

install_zip_binary() {
  local name="$1"
  local version="$2"
  local url="$3"
  local binary="$4"
  local archive="$WORK_DIR/${name}-${version}.zip"
  download "$url" "$archive"
  unzip -o "$archive" -d "$WORK_DIR/$name-$version" >/dev/null
  sudo install -m 0755 "$WORK_DIR/$name-$version/$binary" "$BIN_DIR/$binary"
}

install_tar_binary \
  prometheus "$PROMETHEUS_VERSION" \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${go_arch}.tar.gz" \
  prometheus

install_tar_binary \
  alertmanager "$ALERTMANAGER_VERSION" \
  "https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-${go_arch}.tar.gz" \
  alertmanager

install_tar_binary \
  node_exporter "$NODE_EXPORTER_VERSION" \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${go_arch}.tar.gz" \
  node_exporter

install_tar_binary \
  blackbox_exporter "$BLACKBOX_EXPORTER_VERSION" \
  "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_EXPORTER_VERSION}/blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-${go_arch}.tar.gz" \
  blackbox_exporter

install_zip_binary \
  loki "$LOKI_VERSION" \
  "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-${go_arch}.zip" \
  "loki-linux-${go_arch}"
sudo mv "$BIN_DIR/loki-linux-${go_arch}" "$BIN_DIR/loki"

install_tar_binary \
  tempo "$TEMPO_VERSION" \
  "https://github.com/grafana/tempo/releases/download/v${TEMPO_VERSION}/tempo_${TEMPO_VERSION}_linux_${go_arch}.tar.gz" \
  tempo

install_tar_binary \
  otelcol-contrib "$OTELCOL_VERSION" \
  "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_linux_${go_arch}.tar.gz" \
  otelcol-contrib

if ! command -v grafana-server >/dev/null 2>&1; then
  if [ "$package_manager" = "apt" ]; then
    grafana_deb="$WORK_DIR/grafana_${GRAFANA_VERSION}_${deb_arch}.deb"
    download "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${deb_arch}.deb" "$grafana_deb"
    sudo dpkg -i "$grafana_deb" || sudo apt-get install -f -y
  else
    rpm_arch="$go_arch"
    grafana_rpm="$WORK_DIR/grafana-${GRAFANA_VERSION}-1.${rpm_arch}.rpm"
    download "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}-1.${rpm_arch}.rpm" "$grafana_rpm"
    sudo yum install -y "$grafana_rpm"
  fi
fi

echo "bare-metal prerequisites installed"
