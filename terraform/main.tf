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
  repo_root = abspath("${path.module}/..")
}

resource "local_sensitive_file" "slack_webhook" {
  filename        = "${path.module}/.generated/slack_webhook_url"
  content         = var.slack_webhook_url
  file_permission = "0600"
}

resource "null_resource" "validate_required_files" {
  triggers = {
    compose_hash      = filesha256("${local.repo_root}/docker-compose.yml")
    prometheus_hash   = filesha256("${local.repo_root}/observability/prometheus/prometheus.yml")
    alertmanager_hash = filesha256("${local.repo_root}/observability/alertmanager/alertmanager.yml")
    grafana_ds_hash   = filesha256("${local.repo_root}/observability/grafana/provisioning/datasources/datasources.yml")
  }

  provisioner "local-exec" {
    working_dir = local.repo_root
    command     = "docker compose -f docker-compose.yml config >/dev/null"
  }
}

resource "null_resource" "compose_up" {
  depends_on = [
    local_sensitive_file.slack_webhook,
    null_resource.validate_required_files
  ]

  triggers = {
    always_run   = timestamp()
    compose_hash = filesha256("${local.repo_root}/docker-compose.yml")
    config_hash = sha256(join("", [
      filesha256("${local.repo_root}/observability/prometheus/prometheus.yml"),
      filesha256("${local.repo_root}/observability/loki/loki.yml"),
      filesha256("${local.repo_root}/observability/tempo/tempo.yml"),
      filesha256("${local.repo_root}/observability/otel-collector/config.yml"),
      filesha256("${local.repo_root}/observability/alertmanager/alertmanager.yml")
    ]))
  }

  provisioner "local-exec" {
    working_dir = local.repo_root
    command     = "docker compose -f docker-compose.yml up -d --build"
  }
}
