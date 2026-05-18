terraform {
  required_version = ">= 1.5.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  repo_root     = abspath("${path.module}/..")
  generated_dir = abspath("${path.module}/.generated")

  unit_template_vars = {
    service_user = var.service_user
    config_dir   = var.config_dir
    data_dir     = var.data_dir
    app_dir      = var.app_dir
  }

  systemd_units = {
    prometheus        = "${local.repo_root}/systemd/prometheus.service.tftpl"
    alertmanager      = "${local.repo_root}/systemd/alertmanager.service.tftpl"
    loki              = "${local.repo_root}/systemd/loki.service.tftpl"
    tempo             = "${local.repo_root}/systemd/tempo.service.tftpl"
    otel-collector    = "${local.repo_root}/systemd/otel-collector.service.tftpl"
    node-exporter     = "${local.repo_root}/systemd/node-exporter.service.tftpl"
    blackbox-exporter = "${local.repo_root}/systemd/blackbox-exporter.service.tftpl"
    trainer-api       = "${local.repo_root}/systemd/trainer-api.service.tftpl"
    dora-exporter     = "${local.repo_root}/systemd/dora-exporter.service.tftpl"
  }
}

resource "local_sensitive_file" "slack_webhook" {
  filename        = "${local.generated_dir}/slack_webhook_url"
  content         = var.slack_webhook_url
  file_permission = "0600"
}

resource "local_file" "systemd_units" {
  for_each = local.systemd_units

  filename        = "${local.generated_dir}/systemd/${each.key}.service"
  content         = templatefile(each.value, local.unit_template_vars)
  file_permission = "0644"
}

resource "local_sensitive_file" "grafana_ini" {
  filename = "${local.generated_dir}/grafana/grafana.ini"
  content = templatefile("${local.repo_root}/terraform/templates/grafana.ini.tftpl", {
    grafana_admin_user     = var.grafana_admin_user
    grafana_admin_password = var.grafana_admin_password
  })
  file_permission = "0600"
}

resource "local_sensitive_file" "dora_env" {
  filename = "${local.generated_dir}/secrets/dora-exporter.env"
  content = join("\n", [
    "GITHUB_REPOSITORY=${var.github_repository}",
    "GITHUB_TOKEN=${var.github_token}",
    "DEPLOYMENT_WORKFLOW_NAME=${var.deployment_workflow_name}",
    ""
  ])
  file_permission = "0600"
}

resource "null_resource" "validate_repository_config" {
  triggers = {
    prometheus_hash   = filesha256("${local.repo_root}/observability/prometheus/prometheus.yml")
    alertmanager_hash = filesha256("${local.repo_root}/observability/alertmanager/alertmanager.yml")
    grafana_ds_hash   = filesha256("${local.repo_root}/observability/grafana/provisioning/datasources/datasources.yml")
    otel_hash         = filesha256("${local.repo_root}/observability/otel-collector/config.yml")
    loki_hash         = filesha256("${local.repo_root}/observability/loki/loki.yml")
    tempo_hash        = filesha256("${local.repo_root}/observability/tempo/tempo.yml")
  }

  provisioner "local-exec" {
    working_dir = local.repo_root
    command     = "python3 -m json.tool observability/grafana/dashboards/dora.json >/dev/null && python3 -m json.tool observability/grafana/dashboards/unified-observability.json >/dev/null && python3 -c 'import ast,pathlib; [ast.parse(pathlib.Path(p).read_text()) for p in [\"services/trainer-api/app.py\",\"services/dora-exporter/exporter.py\"]]'"
  }
}

resource "null_resource" "install_bare_metal_prereqs" {
  count = var.install_binaries ? 1 : 0

  triggers = {
    script_hash = filesha256("${local.repo_root}/scripts/baremetal/install_prereqs.sh")
    versions = join(",", [
      var.prometheus_version,
      var.alertmanager_version,
      var.node_exporter_version,
      var.blackbox_exporter_version,
      var.loki_version,
      var.tempo_version,
      var.otelcol_version,
      var.grafana_version
    ])
  }

  provisioner "local-exec" {
    working_dir = local.repo_root
    command     = "bash scripts/baremetal/install_prereqs.sh"
    environment = {
      PROMETHEUS_VERSION        = var.prometheus_version
      ALERTMANAGER_VERSION      = var.alertmanager_version
      NODE_EXPORTER_VERSION     = var.node_exporter_version
      BLACKBOX_EXPORTER_VERSION = var.blackbox_exporter_version
      LOKI_VERSION              = var.loki_version
      TEMPO_VERSION             = var.tempo_version
      OTELCOL_VERSION           = var.otelcol_version
      GRAFANA_VERSION           = var.grafana_version
    }
  }
}

resource "null_resource" "provision_bare_metal_stack" {
  depends_on = [
    local_sensitive_file.slack_webhook,
    local_file.systemd_units,
    local_sensitive_file.grafana_ini,
    local_sensitive_file.dora_env,
    null_resource.validate_repository_config,
    null_resource.install_bare_metal_prereqs
  ]

  triggers = {
    always_run = timestamp()
    repo_root  = local.repo_root
    config_dir = var.config_dir
    data_dir   = var.data_dir
    app_dir    = var.app_dir
  }

  provisioner "local-exec" {
    working_dir = local.repo_root
    command     = "bash scripts/baremetal/provision.sh"
    environment = {
      REPO_ROOT     = local.repo_root
      GENERATED_DIR = local.generated_dir
      CONFIG_DIR    = var.config_dir
      DATA_DIR      = var.data_dir
      APP_DIR       = var.app_dir
      SERVICE_USER  = var.service_user
    }
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = self.triggers.repo_root
    command     = "bash scripts/baremetal/destroy.sh"
    environment = {
      CONFIG_DIR = self.triggers.config_dir
      DATA_DIR   = self.triggers.data_dir
      APP_DIR    = self.triggers.app_dir
    }
  }
}
