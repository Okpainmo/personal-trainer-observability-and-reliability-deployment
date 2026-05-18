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
  default     = "/etc/personal-trainer-observability"
}

variable "data_dir" {
  description = "Bare-metal persistent data root."
  type        = string
  default     = "/var/lib/personal-trainer-observability"
}

variable "app_dir" {
  description = "Application installation root."
  type        = string
  default     = "/opt/personal-trainer-observability"
}

variable "install_binaries" {
  description = "When true, Terraform downloads and installs LGTM/exporter binaries before provisioning services."
  type        = bool
  default     = true
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
