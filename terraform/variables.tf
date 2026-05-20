variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for the alert channel."
  type        = string
  sensitive   = true
  default     = "https://hooks.slack.com/services/REPLACE/ME"
}

variable "grafana_admin_user" {
  description = "Grafana administrator username."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password."
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "service_user" {
  description = "System user that owns and runs the observability services."
  type        = string
  default     = "observability"
}

variable "config_dir" {
  description = "Bare-metal configuration root."
  type        = string
  default     = "/etc/observability-platform"
}

variable "data_dir" {
  description = "Bare-metal persistent data root."
  type        = string
  default     = "/var/lib/observability-platform"
}

variable "app_dir" {
  description = "Application installation root."
  type        = string
  default     = "/opt/observability-platform"
}

variable "install_binaries" {
  description = "When true, Terraform downloads and installs LGTM/exporter binaries before provisioning services."
  type        = bool
  default     = true
}

variable "deploy_test_api" {
  description = "When true, deploy the bundled smoke-test test-api workload."
  type        = bool
  default     = false
}

variable "test_api_port" {
  description = "Port for the optional bundled smoke-test test-api workload."
  type        = number
  default     = 8081
}

variable "monitored_service_name" {
  description = "Logical service name for the application being monitored."
  type        = string
  default     = "personal-trainer-be"
}

variable "monitored_service_metrics_target" {
  description = "Prometheus target for the monitored application's /metrics endpoint."
  type        = string
  default     = "127.0.0.1:8080"
}

variable "monitored_service_metrics_scheme" {
  description = "Scheme Prometheus should use when scraping the monitored application's metrics endpoint."
  type        = string
  default     = "http"

  validation {
    condition     = contains(["http", "https"], var.monitored_service_metrics_scheme)
    error_message = "monitored_service_metrics_scheme must be either \"http\" or \"https\"."
  }
}

variable "monitored_service_metrics_path" {
  description = "HTTP path Prometheus should scrape for monitored application metrics."
  type        = string
  default     = "/metrics"
}

variable "monitored_service_health_url" {
  description = "HTTP URL Blackbox Exporter should probe for the monitored application's health check."
  type        = string
  default     = "http://127.0.0.1:8080/api/v1/health"
}

variable "monitored_service_systemd_unit" {
  description = "systemd unit name for the monitored application. Used by local journald collection or by a remote app-host collector agent."
  type        = string
  default     = "personal-trainer-backend-staging.service"
}

variable "collect_local_monitored_service_logs" {
  description = "When true, the central collector reads the monitored service journal from the observability host. Keep false when the service runs on another server."
  type        = bool
  default     = false
}

variable "extra_http_probe_targets" {
  description = "Additional HTTP URLs for Blackbox Exporter to probe."
  type        = list(string)
  default     = ["http://127.0.0.1:3000/login"]
}

variable "ssl_probe_targets" {
  description = "HTTPS URLs/domains for Blackbox Exporter SSL probes."
  type        = list(string)
  default     = ["https://github.com"]
}

variable "github_repository" {
  description = "GitHub repository in owner/name format for DORA metrics."
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub token with Actions read access for DORA metrics."
  type        = string
  sensitive   = true
  default     = ""
}

variable "deployment_workflow_name" {
  description = "GitHub Actions workflow file/name used as the deployment source."
  type        = string
  default     = "deploy.yml"
}

variable "prometheus_version" {
  type    = string
  default = "2.54.1"
}

variable "alertmanager_version" {
  type    = string
  default = "0.27.0"
}

variable "node_exporter_version" {
  type    = string
  default = "1.8.2"
}

variable "blackbox_exporter_version" {
  type    = string
  default = "0.25.0"
}

variable "loki_version" {
  type    = string
  default = "3.2.0"
}

variable "tempo_version" {
  type    = string
  default = "2.6.0"
}

variable "otelcol_version" {
  type    = string
  default = "0.110.0"
}

variable "grafana_version" {
  type    = string
  default = "11.2.0"
}
